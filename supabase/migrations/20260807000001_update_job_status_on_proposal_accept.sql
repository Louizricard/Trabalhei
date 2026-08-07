-- ============================================================================
-- FreelanceFlow Migration: 20260807000001_update_job_status_on_proposal_accept.sql
-- Descrição: Atualiza o status da vaga para 'in_progress' automaticamente
--            quando uma proposta é aceita pela procedure atômica.
-- ============================================================================

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

    -- 8. Atualizar o status da Vaga para 'in_progress' para sair do mural público
    UPDATE public.jobs
    SET status = 'in_progress', updated_at = NOW()
    WHERE id = v_job.id;

    -- 9. Criar o Contrato no estado estrito 'awaiting_payment' com escrow zerado
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
        0.00,
        'awaiting_payment',
        NOW(),
        NOW(),
        NOW()
    )
    RETURNING id INTO v_contract_id;

    -- 10. Inserir Marcos vinculados ao contrato com status 'pending'
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
                'pending',
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

    -- 11. Criar ou Vincular Conversa no Chat
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

    -- 12. Inserir Mensagem de Sistema avisando sobre a geração do contrato
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
