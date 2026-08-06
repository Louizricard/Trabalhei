-- Migration: 20260806000004_complete_delivery_and_escrow_release.sql
-- Description: Procedimento atômico para liberação de marcos em custódia (Escrow) e repasse ao Freelancer

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
        'payout',
        v_milestone.amount,
        'completed',
        'escrow_release',
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
        -- Finalizar contrato e vaga
        UPDATE public.contracts
        SET 
            status = 'completed',
            completed_at = NOW(),
            updated_at = NOW()
        WHERE id = v_contract.id;

        IF v_contract.job_id IS NOT NULL THEN
            UPDATE public.jobs
            SET 
                status = 'completed',
                updated_at = NOW()
            WHERE id = v_contract.job_id;
        END IF;

        -- Incrementar contagem de jobs completados do freelancer
        UPDATE public.profiles
        SET 
            completed_jobs_count = COALESCE(completed_jobs_count, 0) + 1,
            updated_at = NOW()
        WHERE id = v_contract.freelancer_id;
    END IF;

    -- 9. Notificar no Chat
    SELECT id INTO v_conv_id
    FROM public.conversations
    WHERE contract_id = v_contract.id OR job_id = v_contract.job_id
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_conv_id IS NOT NULL THEN
        INSERT INTO public.messages (
            conversation_id,
            sender_id,
            content,
            message_type,
            is_read
        ) VALUES (
            v_conv_id,
            v_contract.client_id,
            '🎉 Entrega do marco "' || v_milestone.title || '" aprovada com sucesso! O valor de R$ ' || TO_CHAR(v_milestone.amount, 'FM999G999D00') || ' foi liberado e transferido para o saldo da carteira do Freelancer.' || (CASE WHEN v_all_completed THEN ' 🚀 Projeto 100% concluído!' ELSE '' END),
            'system_event',
            false
        );

        UPDATE public.conversations
        SET last_message_at = NOW()
        WHERE id = v_conv_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'milestone_id', v_milestone.id,
        'contract_id', v_contract.id,
        'amount_released', v_milestone.amount,
        'all_completed', v_all_completed
    );
END;
$$;
