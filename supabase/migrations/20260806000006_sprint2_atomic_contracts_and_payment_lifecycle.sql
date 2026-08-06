-- ============================================================================
-- Migration: 20260806000006_sprint2_atomic_contracts_and_payment_lifecycle.sql
-- Description: Sprint 2 - Ciclo de Vida Seguro e Atômico de Contratação e Pagamento
--              1. Suporte a status 'awaiting_payment' em contracts
--              2. Procedure atômica e idempotente accept_proposal_and_create_contract
--              3. Bloqueio de marcos em contratos 'awaiting_payment'
--              4. Ativação idempotente de Escrow em confirm_escrow_deposit
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. ATUALIZAÇÃO DE CONSTRAINTS DE STATUS EM CONTRACTS
-- ----------------------------------------------------------------------------
ALTER TABLE public.contracts DROP CONSTRAINT IF EXISTS contracts_status_check;
ALTER TABLE public.contracts ADD CONSTRAINT contracts_status_check 
    CHECK (status = ANY (ARRAY['awaiting_payment'::text, 'active'::text, 'completed'::text, 'in_dispute'::text, 'cancelled'::text]));

ALTER TABLE public.contracts ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();


-- ----------------------------------------------------------------------------
-- 2. PROCEDURE ATÔMICA E IDEMPOTENTE: accept_proposal_and_create_contract
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.accept_proposal_and_create_contract(
    p_proposal_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_proposal RECORD;
    v_job RECORD;
    v_existing_contract RECORD;
    v_contract_id UUID;
    v_current_user_id UUID;
    v_total_amount NUMERIC;
    v_platform_fee NUMERIC;
    v_m RECORD;
    v_milestone_list JSONB;
    v_conv_id UUID;
BEGIN
    IF p_proposal_id IS NULL THEN
        RAISE EXCEPTION 'ID da proposta é obrigatório.' USING ERRCODE = 'P0002';
    END IF;

    -- Obter ID do usuário solicitante
    BEGIN
        v_current_user_id := NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid;
    EXCEPTION WHEN OTHERS THEN
        v_current_user_id := auth.uid();
    END;

    -- 1. Travar a proposta para evitar concorrência (Lock FOR UPDATE)
    SELECT * INTO v_proposal
    FROM public.proposals
    WHERE id = p_proposal_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Proposta não encontrada.' USING ERRCODE = 'P0002';
    END IF;

    -- 2. Travar o job correspondente
    SELECT * INTO v_job
    FROM public.jobs
    WHERE id = v_proposal.job_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Vaga vinculada à proposta não encontrada.' USING ERRCODE = 'P0002';
    END IF;

    -- 3. Validação de Autoridade: Apenas o cliente dono da vaga pode aceitar
    IF v_current_user_id IS NOT NULL AND v_current_user_id != v_job.client_id THEN
        IF current_user NOT IN ('postgres', 'supabase_admin') AND current_setting('request.jwt.claim.role', true) != 'service_role' THEN
            RAISE EXCEPTION 'Acesso negado: Somente o cliente autor da vaga pode aceitar propostas.' USING ERRCODE = '42501';
        END IF;
    END IF;

    -- 4. Idempotência: Verificar se já existe um contrato gerado para esta proposta
    SELECT * INTO v_existing_contract
    FROM public.contracts
    WHERE proposal_id = p_proposal_id
    LIMIT 1;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'Contrato já existente para esta proposta (Idempotente).',
            'contract_id', v_existing_contract.id,
            'job_id', v_existing_contract.job_id,
            'client_id', v_existing_contract.client_id,
            'freelancer_id', v_existing_contract.freelancer_id,
            'total_amount', v_existing_contract.total_amount,
            'status', v_existing_contract.status,
            'is_new', false
        );
    END IF;

    -- 5. Calcular valores
    v_total_amount := COALESCE(v_proposal.bid_amount, v_proposal.amount, 0.00);
    IF v_total_amount <= 0 THEN
        RAISE EXCEPTION 'Valor da proposta inválido.' USING ERRCODE = '22023';
    END IF;
    v_platform_fee := ROUND(v_total_amount * 0.10, 2);

    -- 6. Atualizar status da proposta para 'accepted'
    UPDATE public.proposals
    SET status = 'accepted', updated_at = NOW()
    WHERE id = p_proposal_id;

    -- 7. Atualizar as outras propostas da mesma vaga para 'rejected'
    UPDATE public.proposals
    SET status = 'rejected', updated_at = NOW()
    WHERE job_id = v_job.id
      AND id != p_proposal_id
      AND status = 'pending';

    -- 8. Criar o Contrato no estado estrito 'awaiting_payment' com escrow zerado
    INSERT INTO public.contracts (
        job_id,
        proposal_id,
        client_id,
        freelancer_id,
        total_amount,
        platform_fee,
        escrow_amount,
        status,
        started_at,
        created_at,
        updated_at
    ) VALUES (
        v_job.id,
        p_proposal_id,
        v_job.client_id,
        v_proposal.freelancer_id,
        v_total_amount,
        v_platform_fee,
        0.00, -- Escrow só é preenchido após liquidação real do pagamento
        'awaiting_payment',
        NOW(),
        NOW(),
        NOW()
    )
    RETURNING id INTO v_contract_id;

    -- 9. Inserir Marcos vinculados ao contrato com status 'pending'
    v_milestone_list := v_proposal.proposed_milestones;
    IF v_milestone_list IS NOT NULL AND jsonb_typeof(v_milestone_list) = 'array' AND jsonb_array_length(v_milestone_list) > 0 THEN
        FOR v_m IN SELECT * FROM jsonb_to_recordset(v_milestone_list) AS x(title text, description text, amount numeric)
        LOOP
            INSERT INTO public.milestones (
                contract_id,
                title,
                description,
                amount,
                status,
                created_at
            ) VALUES (
                v_contract_id,
                COALESCE(v_m.title, 'Marco de Entrega'),
                COALESCE(v_m.description, ''),
                COALESCE(v_m.amount, v_total_amount),
                'pending', -- Aguardando pagamento do escrow
                NOW()
            );
        END LOOP;
    ELSE
        INSERT INTO public.milestones (
            contract_id,
            title,
            description,
            amount,
            status,
            created_at
        ) VALUES (
            v_contract_id,
            'Entrega do Projeto',
            'Conclusão e entrega de todos os requisitos combinados.',
            v_total_amount,
            'pending',
            NOW()
        );
    END IF;

    -- 10. Criar ou Vincular Conversa no Chat
    SELECT id INTO v_conv_id
    FROM public.conversations
    WHERE (client_id = v_job.client_id AND freelancer_id = v_proposal.freelancer_id)
       OR (client_id = v_proposal.freelancer_id AND freelancer_id = v_job.client_id)
       OR (participant_a = v_job.client_id AND participant_b = v_proposal.freelancer_id)
       OR (participant_a = v_proposal.freelancer_id AND participant_b = v_job.client_id)
    LIMIT 1;

    IF v_conv_id IS NULL THEN
        INSERT INTO public.conversations (
            job_id,
            contract_id,
            client_id,
            freelancer_id,
            participant_a,
            participant_b,
            created_at,
            last_message_at
        ) VALUES (
            v_job.id,
            v_contract_id,
            v_job.client_id,
            v_proposal.freelancer_id,
            v_job.client_id,
            v_proposal.freelancer_id,
            NOW(),
            NOW()
        )
        RETURNING id INTO v_conv_id;
    ELSE
        UPDATE public.conversations
        SET contract_id = v_contract_id, last_message_at = NOW()
        WHERE id = v_conv_id;
    END IF;

    -- Inserir Mensagem de Sistema avisando sobre a geração do contrato
    INSERT INTO public.messages (
        conversation_id,
        sender_id,
        content,
        message_type,
        is_read,
        created_at
    ) VALUES (
        v_conv_id,
        v_job.client_id,
        '🤝 Proposta aceita! O Contrato #' || SUBSTRING(v_contract_id::text, 1, 8) || ' foi gerado no valor de R$ ' || TO_CHAR(v_total_amount, 'FM999G999D00') || '. Aguardando depósito da garantia em Escrow pelo Cliente para início das atividades.',
        'system_event',
        false,
        NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Contrato gerado com sucesso em awaiting_payment.',
        'contract_id', v_contract_id,
        'job_id', v_job.id,
        'client_id', v_job.client_id,
        'freelancer_id', v_proposal.freelancer_id,
        'total_amount', v_total_amount,
        'status', 'awaiting_payment',
        'is_new', true
    );
END;
$$;


-- ----------------------------------------------------------------------------
-- 3. BLOQUEIO DE ENTREGAS/LIBERAÇÕES ENQUANTO CONTRATO ESTIVER EM AWAITING_PAYMENT
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_fn_validate_milestone_transition()
RETURNS TRIGGER AS $$
DECLARE
    v_jwt_role text;
    v_current_user_id uuid;
    v_client_id uuid;
    v_freelancer_id uuid;
    v_contract_status text;
BEGIN
    -- Obter informações do contrato
    SELECT client_id, freelancer_id, status 
    INTO v_client_id, v_freelancer_id, v_contract_status
    FROM public.contracts
    WHERE id = NEW.contract_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Contrato vinculado ao marco não encontrado.' USING ERRCODE = 'P0002';
    END IF;

    -- BLOQUEIO CRÍTICO: Se o contrato estiver em awaiting_payment, nenhuma entrega/liberação é permitida
    IF v_contract_status = 'awaiting_payment' AND NEW.status != 'pending' THEN
        RAISE EXCEPTION 'Ação bloqueada: O contrato ainda está aguardando confirmação do pagamento em custódia (Escrow).'
            USING ERRCODE = '42501';
    END IF;

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

        -- 3. Transições permitidas para freelancer (apenas submissão de entrega)
        IF v_current_user_id = v_freelancer_id AND NEW.status IS DISTINCT FROM OLD.status THEN
            IF NEW.status NOT IN ('submitted', 'in_revision') THEN
                RAISE EXCEPTION 'Transição de status inválida para freelancer (% -> %).', OLD.status, NEW.status USING ERRCODE = '42501';
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ----------------------------------------------------------------------------
-- 4. PROCEDIMENTO ATÔMICO E IDEMPOTENTE: confirm_escrow_deposit
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.confirm_escrow_deposit(
    p_gateway_ref TEXT,
    p_paid_amount NUMERIC,
    p_gateway_status TEXT DEFAULT 'approved',
    p_metadata JSONB DEFAULT '{}'::jsonb,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_tx RECORD;
    v_contract_id UUID;
    v_contract RECORD;
    v_job_id UUID;
    v_client_id UUID;
    v_freelancer_id UUID;
    v_conv_id UUID;
    v_uid UUID;
BEGIN
    IF p_gateway_ref IS NULL OR TRIM(p_gateway_ref) = '' THEN
        RAISE EXCEPTION 'ID de referência do gateway é obrigatório.';
    END IF;

    v_uid := COALESCE(p_user_id, auth.uid());

    -- Extrair contract_id do metadata se existir
    IF p_metadata ? 'contract_id' AND p_metadata->>'contract_id' IS NOT NULL THEN
        BEGIN
            v_contract_id := (p_metadata->>'contract_id')::uuid;
        EXCEPTION WHEN OTHERS THEN
            v_contract_id := NULL;
        END;
    END IF;

    -- 1. Localizar e bloquear a transação (Lock FOR UPDATE para evitar concorrência)
    SELECT *
    INTO v_tx
    FROM public.transactions
    WHERE gateway_ref = p_gateway_ref
    FOR UPDATE;

    IF NOT FOUND THEN
        IF v_uid IS NULL AND v_contract_id IS NOT NULL THEN
            SELECT client_id INTO v_uid FROM public.contracts WHERE id = v_contract_id;
        END IF;

        INSERT INTO public.transactions (
            user_id,
            contract_id,
            type,
            gateway_ref,
            amount,
            status,
            gateway_status,
            gateway_provider,
            payment_method,
            metadata
        ) VALUES (
            v_uid,
            v_contract_id,
            'deposit',
            p_gateway_ref,
            p_paid_amount,
            'completed',
            p_gateway_status,
            'mercadopago',
            'pix',
            p_metadata
        )
        RETURNING * INTO v_tx;
    ELSE
        -- 2. Idempotência: Se já foi completada anteriormente e o contrato já está ativo
        IF v_tx.status = 'completed' THEN
            IF v_tx.contract_id IS NOT NULL THEN
                SELECT status INTO v_contract FROM public.contracts WHERE id = v_tx.contract_id;
                IF FOUND AND v_contract.status = 'active' THEN
                    RETURN jsonb_build_object(
                        'success', true,
                        'message', 'Depósito e Escrow já confirmados anteriormente (Idempotente).',
                        'transaction_id', v_tx.id,
                        'contract_id', v_tx.contract_id,
                        'already_processed', true
                    );
                END IF;
            END IF;
        END IF;

        -- Atualizar status da transação
        UPDATE public.transactions
        SET 
            status = 'completed',
            gateway_status = p_gateway_status,
            metadata = COALESCE(metadata, '{}'::jsonb) || p_metadata,
            amount = COALESCE(p_paid_amount, amount),
            updated_at = NOW()
        WHERE id = v_tx.id;
    END IF;

    v_contract_id := v_tx.contract_id;

    -- Se não achou contract_id na transação, verificar no metadata
    IF v_contract_id IS NULL AND p_metadata ? 'contract_id' AND p_metadata->>'contract_id' IS NOT NULL THEN
        BEGIN
            v_contract_id := (p_metadata->>'contract_id')::uuid;
            UPDATE public.transactions SET contract_id = v_contract_id WHERE id = v_tx.id;
        EXCEPTION WHEN OTHERS THEN
            v_contract_id := NULL;
        END;
    END IF;

    -- 3. Se houver contrato associado, ATIVAR o Contrato e alimentar o Escrow
    IF v_contract_id IS NOT NULL THEN
        SELECT * INTO v_contract
        FROM public.contracts
        WHERE id = v_contract_id
        FOR UPDATE;

        IF FOUND THEN
            -- Ativar contrato e definir escrow_amount
            UPDATE public.contracts
            SET 
                escrow_amount = COALESCE(escrow_amount, 0) + COALESCE(p_paid_amount, v_tx.amount),
                status = 'active',
                updated_at = NOW()
            WHERE id = v_contract_id;

            -- Ativar todos os marcos vinculados para funded_in_escrow
            UPDATE public.milestones
            SET status = 'funded_in_escrow'
            WHERE contract_id = v_contract_id
              AND status = 'pending';

            -- Atualizar status da vaga para 'in_progress'
            IF v_contract.job_id IS NOT NULL THEN
                UPDATE public.jobs
                SET 
                    status = 'in_progress',
                    updated_at = NOW()
                WHERE id = v_contract.job_id;
            END IF;

            -- Creditar saldo em custódia no perfil do cliente
            IF v_contract.client_id IS NOT NULL THEN
                UPDATE public.profiles
                SET 
                    escrow_balance = COALESCE(escrow_balance, 0) + COALESCE(p_paid_amount, v_tx.amount),
                    updated_at = NOW()
                WHERE id = v_contract.client_id;
            END IF;

            -- 4. Notificar no Chat em tempo real
            SELECT id INTO v_conv_id
            FROM public.conversations
            WHERE contract_id = v_contract_id OR job_id = v_contract.job_id
            ORDER BY created_at DESC
            LIMIT 1;

            IF v_conv_id IS NOT NULL THEN
                INSERT INTO public.messages (
                    conversation_id,
                    sender_id,
                    content,
                    message_type,
                    is_read,
                    created_at
                ) VALUES (
                    v_conv_id,
                    v_contract.client_id,
                    '🎉 Pagamento de R$ ' || TO_CHAR(COALESCE(p_paid_amount, v_tx.amount), 'FM999G999D00') || ' confirmado! O valor está retido em custódia segura (Escrow). O projeto está oficialmente EM ANDAMENTO!',
                    'system_event',
                    false,
                    NOW()
                );

                UPDATE public.conversations
                SET last_message_at = NOW()
                WHERE id = v_conv_id;
            END IF;
        END IF;
    ELSIF v_tx.user_id IS NOT NULL THEN
        -- Depósito em carteira avulso
        UPDATE public.profiles
        SET 
            wallet_balance = COALESCE(wallet_balance, 0) + COALESCE(p_paid_amount, v_tx.amount),
            updated_at = NOW()
        WHERE id = v_tx.user_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'transaction_id', v_tx.id,
        'contract_id', v_contract_id,
        'amount_credited', COALESCE(p_paid_amount, v_tx.amount),
        'contract_status', 'active'
    );
END;
$$;

-- Notificar PostgREST para recarregar schema cache
NOTIFY pgrst, 'reload schema';
