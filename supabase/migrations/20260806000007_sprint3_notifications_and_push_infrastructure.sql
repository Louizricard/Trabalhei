-- ============================================================================
-- SPRINT 3 MIGRATION: Infraestrutura de Notificações In-App & Push (FCM)
-- ============================================================================

-- 1. TABELA DE TOKENS PUSH (Múltiplos dispositivos por usuário)
CREATE TABLE IF NOT EXISTS public.user_push_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE,
    platform TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'web', 'macos', 'windows', 'linux')),
    device_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices de performance para busca de tokens
CREATE INDEX IF NOT EXISTS idx_user_push_tokens_user_id ON public.user_push_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_user_push_tokens_token ON public.user_push_tokens(token);

-- RLS para user_push_tokens
ALTER TABLE public.user_push_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own push tokens" ON public.user_push_tokens;
CREATE POLICY "Users can view their own push tokens"
    ON public.user_push_tokens FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own push tokens" ON public.user_push_tokens;
CREATE POLICY "Users can insert their own push tokens"
    ON public.user_push_tokens FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own push tokens" ON public.user_push_tokens;
CREATE POLICY "Users can update their own push tokens"
    ON public.user_push_tokens FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own push tokens" ON public.user_push_tokens;
CREATE POLICY "Users can delete their own push tokens"
    ON public.user_push_tokens FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- 2. TABELA DE NOTIFICAÇÕES IN-APP (Fonte da Verdade & Realtime)
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN (
        'new_message',
        'proposal_received',
        'proposal_accepted',
        'contract_active',
        'milestone_submitted',
        'milestone_in_revision',
        'milestone_approved',
        'dispute_opened',
        'payment_received',
        'system'
    )),
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices para histórico de notificações e contagem de não lidas
CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON public.notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON public.notifications(user_id, is_read) WHERE is_read = false;

-- Habilita Realtime para notifications (garante sincronização instantânea com o app)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
          AND schemaname = 'public' 
          AND tablename = 'notifications'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
END $$;

-- RLS para notifications
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own notifications" ON public.notifications;
CREATE POLICY "Users can view their own notifications"
    ON public.notifications FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update is_read of their own notifications" ON public.notifications;
CREATE POLICY "Users can update is_read of their own notifications"
    ON public.notifications FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own notifications" ON public.notifications;
CREATE POLICY "Users can delete their own notifications"
    ON public.notifications FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- Inserções diretas por authenticated/anon são bloqueadas; apenas triggers/RPCs (SECURITY DEFINER) criam notificações.
DROP POLICY IF EXISTS "Block direct inserts to notifications" ON public.notifications;
CREATE POLICY "Block direct inserts to notifications"
    ON public.notifications FOR INSERT
    TO authenticated, anon
    WITH CHECK (false);

-- 3. PROCEDURE SEGURA & NÃO-BLOQUEANTE: create_notification
CREATE OR REPLACE FUNCTION public.create_notification(
    p_user_id UUID,
    p_title TEXT,
    p_body TEXT,
    p_type TEXT,
    p_data JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_notification_id UUID;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN NULL;
    END IF;

    INSERT INTO public.notifications (user_id, title, body, type, data)
    VALUES (p_user_id, p_title, p_body, p_type, COALESCE(p_data, '{}'::jsonb))
    RETURNING id INTO v_notification_id;

    RETURN v_notification_id;
EXCEPTION
    WHEN OTHERS THEN
        -- O envio de notificação NUNCA deve quebrar ou abortar a transação principal de negócio
        RAISE WARNING 'Erro ao registrar notificação (user %): %', p_user_id, SQLERRM;
        RETURN NULL;
END;
$$;

-- 4. PROCEDURE: mark_all_notifications_as_read
CREATE OR REPLACE FUNCTION public.mark_all_notifications_as_read()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_count INT;
BEGIN
    UPDATE public.notifications
    SET is_read = true
    WHERE user_id = auth.uid() AND is_read = false;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;

-- 5. TRIGGER: Nova Mensagem no Chat -> Notificar Destinatário
CREATE OR REPLACE FUNCTION public.trg_fn_notify_on_new_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_conv RECORD;
    v_recipient_id UUID;
    v_sender_name TEXT;
    v_preview TEXT;
BEGIN
    -- Busca participantes da conversa
    SELECT client_id, freelancer_id, participant_a, participant_b 
    INTO v_conv
    FROM public.conversations
    WHERE id = NEW.conversation_id;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    -- Identifica o destinatário
    IF NEW.sender_id = v_conv.client_id THEN
        v_recipient_id := v_conv.freelancer_id;
    ELSIF NEW.sender_id = v_conv.freelancer_id THEN
        v_recipient_id := v_conv.client_id;
    ELSIF NEW.sender_id = v_conv.participant_a THEN
        v_recipient_id := v_conv.participant_b;
    ELSE
        v_recipient_id := v_conv.participant_a;
    END IF;

    IF v_recipient_id IS NULL OR v_recipient_id = NEW.sender_id THEN
        RETURN NEW;
    END IF;

    -- Busca nome do remetente
    SELECT COALESCE(full_name, 'Alguém') INTO v_sender_name
    FROM public.profiles
    WHERE id = NEW.sender_id;

    -- Prepara o preview da mensagem
    IF NEW.message_type = 'file' OR NEW.attachment_url IS NOT NULL THEN
        v_preview := '📎 Enviou um anexo';
    ELSE
        v_preview := LEFT(COALESCE(NEW.content, 'Nova mensagem'), 120);
    END IF;

    -- Cria notificação
    PERFORM public.create_notification(
        v_recipient_id,
        v_sender_name,
        v_preview,
        'new_message',
        jsonb_build_object(
            'route', '/chat/' || NEW.conversation_id::text,
            'conversation_id', NEW.conversation_id,
            'sender_id', NEW.sender_id,
            'message_id', NEW.id
        )
    );

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Falha no trigger trg_fn_notify_on_new_message: %', SQLERRM;
        RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_new_message ON public.messages;
CREATE TRIGGER trg_notify_on_new_message
    AFTER INSERT ON public.messages
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_fn_notify_on_new_message();

-- 6. TRIGGER: Nova Proposta Recebida -> Notificar Contratante
CREATE OR REPLACE FUNCTION public.trg_fn_notify_on_new_proposal()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_job RECORD;
    v_freelancer_name TEXT;
BEGIN
    SELECT title, client_id INTO v_job
    FROM public.jobs
    WHERE id = NEW.job_id;

    IF NOT FOUND OR v_job.client_id IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT COALESCE(full_name, 'Um profissional') INTO v_freelancer_name
    FROM public.profiles
    WHERE id = NEW.freelancer_id;

    PERFORM public.create_notification(
        v_job.client_id,
        'Nova proposta recebida',
        v_freelancer_name || ' enviou uma proposta para "' || LEFT(v_job.title, 50) || '"',
        'proposal_received',
        jsonb_build_object(
            'route', '/jobs/' || NEW.job_id::text || '/proposals',
            'job_id', NEW.job_id,
            'proposal_id', NEW.id
        )
    );

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Falha no trigger trg_fn_notify_on_new_proposal: %', SQLERRM;
        RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_new_proposal ON public.proposals;
CREATE TRIGGER trg_notify_on_new_proposal
    AFTER INSERT ON public.proposals
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_fn_notify_on_new_proposal();

-- 7. TRIGGER: Contrato Ativado (Escrow Confirmado) -> Notificar Freelancer
CREATE OR REPLACE FUNCTION public.trg_fn_notify_on_contract_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_conv_id UUID;
BEGIN
    -- Quando o contrato é ativado (sai de awaiting_payment para active)
    IF OLD.status = 'awaiting_payment' AND NEW.status = 'active' THEN
        -- Busca conversa vinculada
        SELECT id INTO v_conv_id
        FROM public.conversations
        WHERE contract_id = NEW.id OR job_id = NEW.job_id
        LIMIT 1;

        PERFORM public.create_notification(
            NEW.freelancer_id,
            '🎉 Pagamento em Custódia Confirmado!',
            'O cliente realizou o depósito de garantia. O contrato está ativo e você já pode trabalhar com segurança.',
            'contract_active',
            jsonb_build_object(
                'route', CASE WHEN v_conv_id IS NOT NULL THEN '/chat/' || v_conv_id::text ELSE '/dashboard' END,
                'contract_id', NEW.id,
                'job_id', NEW.job_id
            )
        );
    END IF;

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Falha no trigger trg_fn_notify_on_contract_status_change: %', SQLERRM;
        RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_contract_status_change ON public.contracts;
CREATE TRIGGER trg_notify_on_contract_status_change
    AFTER UPDATE OF status ON public.contracts
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_fn_notify_on_contract_status_change();

-- 8. TRIGGER: Mudança de Status de Marcos (Entrega, Revisão, Aprovação)
CREATE OR REPLACE FUNCTION public.trg_fn_notify_on_milestone_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_contract RECORD;
    v_conv_id UUID;
    v_route TEXT;
BEGIN
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;

    SELECT client_id, freelancer_id, job_id INTO v_contract
    FROM public.contracts
    WHERE id = NEW.contract_id;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    SELECT id INTO v_conv_id
    FROM public.conversations
    WHERE contract_id = NEW.contract_id OR job_id = v_contract.job_id
    LIMIT 1;

    v_route := CASE WHEN v_conv_id IS NOT NULL THEN '/chat/' || v_conv_id::text ELSE '/dashboard' END;

    -- Caso 1: Marco Submetido pelo Freelancer -> Notificar Cliente
    IF NEW.status = 'submitted' THEN
        PERFORM public.create_notification(
            v_contract.client_id,
            'Entrega realizada para revisão',
            'O profissional enviou os entregáveis do marco "' || LEFT(NEW.title, 50) || '".',
            'milestone_submitted',
            jsonb_build_object(
                'route', v_route,
                'contract_id', NEW.contract_id,
                'milestone_id', NEW.id
            )
        );

    -- Caso 2: Cliente solicitou revisão -> Notificar Freelancer
    ELSIF NEW.status = 'in_revision' THEN
        PERFORM public.create_notification(
            v_contract.freelancer_id,
            'Ajustes solicitados no marco',
            'O cliente solicitou revisões no marco "' || LEFT(NEW.title, 50) || '".',
            'milestone_in_revision',
            jsonb_build_object(
                'route', v_route,
                'contract_id', NEW.contract_id,
                'milestone_id', NEW.id
            )
        );

    -- Caso 3: Marco Aprovado & Liberado -> Notificar Freelancer
    ELSIF NEW.status = 'approved_and_released' THEN
        PERFORM public.create_notification(
            v_contract.freelancer_id,
            '💰 Pagamento Liberado!',
            'O marco "' || LEFT(NEW.title, 50) || '" foi aprovado e o valor foi transferido para sua carteira.',
            'milestone_approved',
            jsonb_build_object(
                'route', '/payments',
                'contract_id', NEW.contract_id,
                'milestone_id', NEW.id
            )
        );
    END IF;

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Falha no trigger trg_fn_notify_on_milestone_status_change: %', SQLERRM;
        RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_milestone_status_change ON public.milestones;
CREATE TRIGGER trg_notify_on_milestone_status_change
    AFTER UPDATE OF status ON public.milestones
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_fn_notify_on_milestone_status_change();
