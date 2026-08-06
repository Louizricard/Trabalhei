-- ============================================================================
-- Migration: 20260806000005_sprint1_rls_security_hardening.sql
-- Description: Hardening definitivo de RLS, Triggers e Integridade Financeira
--              1. Proteção estrita contra injeção de saldo/admin em profiles
--              2. Revogação de INSERT/UPDATE/DELETE em transactions por usuários
--              3. Restrição de RLS e validação de transições de status em milestones
--              4. Garantia de updated_at em contracts para compatibilidade de RPCs
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. COMPATIBILIDADE DE SCHEMA (CONTRACTS)
-- ----------------------------------------------------------------------------
ALTER TABLE public.contracts ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- ----------------------------------------------------------------------------
-- 1. TABELA PROFILES: TRIGGER DE PROTEÇÃO DE CAMPOS SENSÍVEIS
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_fn_protect_profile_sensitive_fields()
RETURNS TRIGGER AS $$
DECLARE
    v_jwt_role text;
BEGIN
    -- Permitir que superusuários internos e funções SECURITY DEFINER operem
    IF current_user IN ('postgres', 'supabase_admin') THEN
        RETURN NEW;
    END IF;

    BEGIN
        v_jwt_role := current_setting('request.jwt.claim.role', true);
    EXCEPTION WHEN OTHERS THEN
        v_jwt_role := NULL;
    END;

    IF v_jwt_role = 'service_role' THEN
        RETURN NEW;
    END IF;

    -- Se o request vem de cliente direto (authenticated ou anon), aplicar restrição total
    IF v_jwt_role IN ('authenticated', 'anon') OR current_user IN ('authenticated', 'anon') THEN
        -- 1. Bloqueio de saldos financeiros
        IF NEW.wallet_balance IS DISTINCT FROM OLD.wallet_balance THEN
            RAISE EXCEPTION 'Acesso negado: Não é permitido alterar wallet_balance diretamente. Utilize as operações financeiras oficiais.'
                USING ERRCODE = '42501';
        END IF;

        IF NEW.escrow_balance IS DISTINCT FROM OLD.escrow_balance THEN
            RAISE EXCEPTION 'Acesso negado: Não é permitido alterar escrow_balance diretamente.'
                USING ERRCODE = '42501';
        END IF;

        -- 2. Bloqueio de métricas de reputação e verificação
        IF NEW.rating IS DISTINCT FROM OLD.rating THEN
            RAISE EXCEPTION 'Acesso negado: Não é permitido alterar rating diretamente.'
                USING ERRCODE = '42501';
        END IF;

        IF NEW.completed_jobs_count IS DISTINCT FROM OLD.completed_jobs_count THEN
            RAISE EXCEPTION 'Acesso negado: Não é permitido alterar completed_jobs_count diretamente.'
                USING ERRCODE = '42501';
        END IF;

        IF NEW.is_verified IS DISTINCT FROM OLD.is_verified THEN
            RAISE EXCEPTION 'Acesso negado: Não é permitido alterar is_verified diretamente.'
                USING ERRCODE = '42501';
        END IF;

        -- 3. Bloqueio de elevação para administrador
        IF NEW.role IS DISTINCT FROM OLD.role THEN
            IF NEW.role = 'admin' THEN
                RAISE EXCEPTION 'Acesso negado: Não é permitido autoatribuir privilégios de administrador.'
                    USING ERRCODE = '42501';
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_protect_profile_sensitive_fields ON public.profiles;
CREATE TRIGGER trg_protect_profile_sensitive_fields
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_fn_protect_profile_sensitive_fields();


-- ----------------------------------------------------------------------------
-- 2. TABELA TRANSACTIONS: REVOGAÇÃO DE INSERÇÕES E POLICIES RESIDUAIS
-- ----------------------------------------------------------------------------

ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

-- Dropar todas as policies legadas ou permissivas
DROP POLICY IF EXISTS "Users can create transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users can insert own transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users can update own transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users can delete own transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users can view own transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users can read own transactions" ON public.transactions;

-- Política de leitura estrita (somente o dono pode consultar suas transações)
CREATE POLICY "Users can read own transactions"
ON public.transactions
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Revogar qualquer permissão de modificação direta para authenticated e anon
REVOKE INSERT, UPDATE, DELETE ON public.transactions FROM anon, authenticated;
GRANT SELECT ON public.transactions TO authenticated;


-- ----------------------------------------------------------------------------
-- 3. TABELA MILESTONES: MÁQUINA DE ESTADOS E RLS RESTRITA
-- ----------------------------------------------------------------------------

ALTER TABLE public.milestones ENABLE ROW LEVEL SECURITY;

-- Dropar policies permissivas
DROP POLICY IF EXISTS "Contract parties can manage milestones" ON public.milestones;
DROP POLICY IF EXISTS "Milestones viewable by contract parties" ON public.milestones;
DROP POLICY IF EXISTS "Clients can manage contract milestones" ON public.milestones;
DROP POLICY IF EXISTS "Contract parties can update milestone deliverables" ON public.milestones;

-- Leitura permitida exclusivamente para os participantes do contrato
CREATE POLICY "Milestones viewable by contract parties"
ON public.milestones
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.contracts c
        WHERE c.id = milestones.contract_id
        AND (c.client_id = auth.uid() OR c.freelancer_id = auth.uid())
    )
);

-- Atualização restrita aos participantes do contrato
CREATE POLICY "Contract parties can update milestone deliverables"
ON public.milestones
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.contracts c
        WHERE c.id = milestones.contract_id
        AND (c.client_id = auth.uid() OR c.freelancer_id = auth.uid())
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.contracts c
        WHERE c.id = milestones.contract_id
        AND (c.client_id = auth.uid() OR c.freelancer_id = auth.uid())
    )
);

-- Revogar exclusão direta de marcos
REVOKE DELETE ON public.milestones FROM anon, authenticated;

-- Trigger de Máquina de Estados e Validação de Transições em Milestones
CREATE OR REPLACE FUNCTION public.trg_fn_validate_milestone_transition()
RETURNS TRIGGER AS $$
DECLARE
    v_jwt_role text;
    v_current_user_id uuid;
    v_client_id uuid;
    v_freelancer_id uuid;
    v_contract_status text;
BEGIN
    BEGIN
        v_jwt_role := current_setting('request.jwt.claim.role', true);
    EXCEPTION WHEN OTHERS THEN
        v_jwt_role := NULL;
    END;

    IF v_jwt_role IN ('authenticated', 'anon') THEN
        BEGIN
            v_current_user_id := NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid;
        EXCEPTION WHEN OTHERS THEN
            v_current_user_id := auth.uid();
        END;

        -- Obter informações do contrato
        SELECT client_id, freelancer_id, status 
        INTO v_client_id, v_freelancer_id, v_contract_status
        FROM public.contracts
        WHERE id = NEW.contract_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Contrato vinculado ao marco não encontrado.' USING ERRCODE = 'P0002';
        END IF;

        -- Verificar se o usuário faz parte do contrato
        IF v_current_user_id IS NOT NULL AND v_current_user_id NOT IN (v_client_id, v_freelancer_id) THEN
            RAISE EXCEPTION 'Acesso negado: Você não tem permissão para alterar este marco.' USING ERRCODE = '42501';
        END IF;

        -- Não permitir alteração do valor do marco após criação
        IF NEW.amount IS DISTINCT FROM OLD.amount THEN
            RAISE EXCEPTION 'Não é permitido alterar o valor de um marco já cadastrado.' USING ERRCODE = '42501';
        END IF;

        -- 1. Status approved_and_released é imutável
        IF OLD.status = 'approved_and_released' AND (NEW.deliverable_notes IS DISTINCT FROM OLD.deliverable_notes OR NEW.status IS DISTINCT FROM OLD.status) THEN
            RAISE EXCEPTION 'Um marco já aprovado e liberado não pode ser modificado.' USING ERRCODE = '42501';
        END IF;

        -- 2. Freelancer não pode aprovar ou liberar fundos de marcos diretamente
        IF v_current_user_id = v_freelancer_id AND NEW.status = 'approved_and_released' THEN
            RAISE EXCEPTION 'Freelancers não podem autoaprovar ou liberar fundos de marcos.' USING ERRCODE = '42501';
        END IF;

        -- 3. Transições permitidas para freelancer (submeter entrega)
        IF v_current_user_id = v_freelancer_id AND NEW.status IS DISTINCT FROM OLD.status THEN
            IF NEW.status NOT IN ('submitted', 'in_revision') THEN
                RAISE EXCEPTION 'Transição de status inválida para freelancer (% -> %).', OLD.status, NEW.status USING ERRCODE = '42501';
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_validate_milestone_transition ON public.milestones;
CREATE TRIGGER trg_validate_milestone_transition
    BEFORE UPDATE ON public.milestones
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_fn_validate_milestone_transition();

-- ----------------------------------------------------------------------------
-- 4. PROCEDIMENTO ATÔMICO DE LIBERAÇÃO DE ESCROW
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.release_escrow_milestone(
    p_milestone_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_milestone RECORD;
    v_contract RECORD;
    v_all_completed BOOLEAN;
    v_conv_id UUID;
BEGIN
    IF p_milestone_id IS NULL THEN
        RAISE EXCEPTION 'ID do marco é obrigatório.';
    END IF;

    -- 1. Bloquear o marco para evitar concorrência
    SELECT * INTO v_milestone
    FROM public.milestones
    WHERE id = p_milestone_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Marco não encontrado.';
    END IF;

    IF v_milestone.status = 'approved_and_released' THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'Marco já foi liberado anteriormente.'
        );
    END IF;

    -- 2. Bloquear o contrato
    SELECT * INTO v_contract
    FROM public.contracts
    WHERE id = v_milestone.contract_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Contrato não encontrado.';
    END IF;

    -- 3. Atualizar status do marco para 'approved_and_released'
    UPDATE public.milestones
    SET 
        status = 'approved_and_released'
    WHERE id = p_milestone_id;

    -- 4. Deduzir o valor de escrow_amount do contrato
    UPDATE public.contracts
    SET 
        escrow_amount = GREATEST(0, COALESCE(escrow_amount, 0) - v_milestone.amount),
        updated_at = NOW()
    WHERE id = v_contract.id;

    -- 5. Creditar o valor líquido na carteira do Freelancer (profiles.wallet_balance)
    UPDATE public.profiles
    SET 
        wallet_balance = COALESCE(wallet_balance, 0) + v_milestone.amount,
        updated_at = NOW()
    WHERE id = v_contract.freelancer_id;

    -- 6. Deduzir escrow_balance do cliente se tiver
    UPDATE public.profiles
    SET 
        escrow_balance = GREATEST(0, COALESCE(escrow_balance, 0) - v_milestone.amount),
        updated_at = NOW()
    WHERE id = v_contract.client_id;

    -- 7. Registrar a transação na tabela transactions para o freelancer
    INSERT INTO public.transactions (
        user_id,
        contract_id,
        type,
        amount,
        status,
        gateway_provider,
        metadata
    ) VALUES (
        v_contract.freelancer_id,
        v_contract.id,
        'escrow_release',
        v_milestone.amount,
        'completed',
        'mercadopago',
        jsonb_build_object(
            'milestone_id', v_milestone.id,
            'milestone_title', v_milestone.title,
            'client_id', v_contract.client_id,
            'job_id', v_contract.job_id,
            'released_at', NOW()
        )
    );

    -- 8. Verificar se todos os marcos do contrato foram aprovados
    SELECT NOT EXISTS (
        SELECT 1 FROM public.milestones
        WHERE contract_id = v_contract.id
          AND status != 'approved_and_released'
    ) INTO v_all_completed;

    IF v_all_completed THEN
        UPDATE public.contracts
        SET 
            status = 'completed',
            completed_at = NOW(),
            updated_at = NOW()
        WHERE id = v_contract.id;

        UPDATE public.jobs
        SET status = 'completed'
        WHERE id = v_contract.job_id;

        -- Incrementar contadores de jobs completados
        UPDATE public.profiles
        SET 
            completed_jobs_count = COALESCE(completed_jobs_count, 0) + 1,
            updated_at = NOW()
        WHERE id IN (v_contract.client_id, v_contract.freelancer_id);
    END IF;

    -- 9. Inserir mensagem de sistema no chat se existir conversa
    SELECT id INTO v_conv_id
    FROM public.conversations
    WHERE (client_id = v_contract.client_id AND freelancer_id = v_contract.freelancer_id)
       OR (client_id = v_contract.freelancer_id AND freelancer_id = v_contract.client_id)
    LIMIT 1;

    IF v_conv_id IS NOT NULL THEN
        INSERT INTO public.messages (
            conversation_id,
            sender_id,
            content,
            type,
            metadata
        ) VALUES (
            v_conv_id,
            v_contract.client_id,
            '✅ Marco "' || v_milestone.title || '" foi aprovado e o pagamento de R$ ' || TO_CHAR(v_milestone.amount, 'FM999G999G990D00') || ' foi liberado para a carteira do Freelancer!',
            'system',
            jsonb_build_object(
                'event', 'milestone_released',
                'milestone_id', v_milestone.id,
                'amount', v_milestone.amount
            )
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'milestone_id', v_milestone.id,
        'released_amount', v_milestone.amount,
        'contract_completed', v_all_completed
    );
END;
$$;

-- Notificar PostgREST para recarregar o schema cache
NOTIFY pgrst, 'reload schema';
