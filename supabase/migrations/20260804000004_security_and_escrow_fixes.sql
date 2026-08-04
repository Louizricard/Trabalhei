-- ============================================================================
-- Migration: 20260804000004_security_and_escrow_fixes.sql
-- Description: Revoga inserção direta na tabela transactions e adiciona Stored Procedures seguras para Escrow e Saques Pix
-- ============================================================================

-- 1. REVOGAR POLICY INSEGURA DE INSERÇÃO DIRETA EM TRANSACTIONS
DROP POLICY IF EXISTS "Users can insert own transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users can create transactions" ON public.transactions;

-- Garantir policy de leitura segura para o proprietário
DROP POLICY IF EXISTS "Users can read own transactions" ON public.transactions;
CREATE POLICY "Users can read own transactions"
    ON public.transactions FOR SELECT
    USING (auth.uid() = user_id);

-- 2. STORED PROCEDURE: release_escrow_milestone (Aprovação e Liberação de Marco com Escrow)
CREATE OR REPLACE FUNCTION public.release_escrow_milestone(
    p_milestone_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_caller_id UUID;
    v_contract_id UUID;
    v_client_id UUID;
    v_freelancer_id UUID;
    v_milestone_amount NUMERIC(10,2);
    v_current_status TEXT;
    v_platform_fee NUMERIC(10,2);
    v_net_amount NUMERIC(10,2);
    v_all_completed BOOLEAN;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Não autenticado';
    END IF;

    -- Obter detalhes do marco e contrato
    SELECT 
        m.contract_id,
        m.amount,
        m.status,
        c.client_id,
        c.freelancer_id
    INTO
        v_contract_id,
        v_milestone_amount,
        v_current_status,
        v_client_id,
        v_freelancer_id
    FROM public.milestones m
    JOIN public.contracts c ON c.id = m.contract_id
    WHERE m.id = p_milestone_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Marco não encontrado';
    END IF;

    -- Validar que apenas o contratante (cliente) pode liberar o escrow
    IF v_caller_id != v_client_id THEN
        RAISE EXCEPTION 'Apenas o cliente contratante pode aprovar e liberar o pagamento deste marco';
    END IF;

    IF v_current_status = 'approved_and_released' THEN
        RAISE EXCEPTION 'Este marco já foi aprovado e liberado anteriormente';
    END IF;

    -- Calcular taxa da plataforma (5%) e valor líquido do freelancer
    v_platform_fee := ROUND(v_milestone_amount * 0.05, 2);
    v_net_amount := v_milestone_amount - v_platform_fee;

    -- 1. Atualizar status do marco
    UPDATE public.milestones
    SET 
        status = 'approved_and_released',
        updated_at = NOW()
    WHERE id = p_milestone_id;

    -- 2. Creditar o saldo na carteira do freelancer
    UPDATE public.profiles
    SET 
        wallet_balance = COALESCE(wallet_balance, 0) + v_net_amount,
        updated_at = NOW()
    WHERE id = v_freelancer_id;

    -- 3. Debitar o saldo em escrow do contrato
    UPDATE public.contracts
    SET 
        escrow_amount = GREATEST(0, COALESCE(escrow_amount, 0) - v_milestone_amount),
        updated_at = NOW()
    WHERE id = v_contract_id;

    -- 4. Registrar as transações auditáveis
    INSERT INTO public.transactions (
        user_id,
        contract_id,
        type,
        amount,
        status
    ) VALUES (
        v_freelancer_id,
        v_contract_id,
        'escrow_release',
        v_net_amount,
        'completed'
    );

    IF v_platform_fee > 0 THEN
        INSERT INTO public.transactions (
            user_id,
            contract_id,
            type,
            amount,
            status
        ) VALUES (
            v_freelancer_id,
            v_contract_id,
            'platform_fee',
            v_platform_fee,
            'completed'
        );
    END IF;

    -- 5. Verificar se todos os marcos foram liberados para concluir o contrato
    SELECT NOT EXISTS (
        SELECT 1 
        FROM public.milestones 
        WHERE contract_id = v_contract_id 
          AND status != 'approved_and_released'
    ) INTO v_all_completed;

    IF v_all_completed THEN
        UPDATE public.contracts
        SET 
            status = 'completed',
            updated_at = NOW()
        WHERE id = v_contract_id;

        -- Atualizar status da vaga vinculada para concluída
        UPDATE public.jobs
        SET 
            status = 'completed',
            updated_at = NOW()
        WHERE id = (SELECT job_id FROM public.contracts WHERE id = v_contract_id);
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'milestone_id', p_milestone_id,
        'released_amount', v_net_amount,
        'platform_fee', v_platform_fee,
        'contract_completed', v_all_completed
    );
END;
$$;

-- 3. STORED PROCEDURE: request_pix_payout (Solicitação Atômica e Segura de Saque Pix)
CREATE OR REPLACE FUNCTION public.request_pix_payout(
    p_amount NUMERIC,
    p_pix_key TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_caller_id UUID;
    v_current_balance NUMERIC(10,2);
    v_new_balance NUMERIC(10,2);
    v_tx_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Não autenticado';
    END IF;

    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Valor de saque inválido. O valor deve ser maior que zero.';
    END IF;

    IF p_pix_key IS NULL OR TRIM(p_pix_key) = '' THEN
        RAISE EXCEPTION 'Chave Pix é obrigatória para processamento do saque.';
    END IF;

    -- Obter e bloquear linha do perfil para evitar saques concorrentes (Race Conditions)
    SELECT wallet_balance
    INTO v_current_balance
    FROM public.profiles
    WHERE id = v_caller_id
    FOR UPDATE;

    IF v_current_balance IS NULL OR v_current_balance < p_amount THEN
        RAISE EXCEPTION 'Saldo insuficiente para saque. Saldo disponível: R$ %', COALESCE(v_current_balance, 0);
    END IF;

    -- Debitar do saldo da carteira
    v_new_balance := v_current_balance - p_amount;

    UPDATE public.profiles
    SET 
        wallet_balance = v_new_balance,
        updated_at = NOW()
    WHERE id = v_caller_id;

    -- Registrar a transação de saque Pix
    INSERT INTO public.transactions (
        user_id,
        type,
        amount,
        status,
        pix_key
    ) VALUES (
        v_caller_id,
        'payout_pix',
        p_amount,
        'completed',
        p_pix_key
    ) RETURNING id INTO v_tx_id;

    RETURN jsonb_build_object(
        'success', true,
        'transaction_id', v_tx_id,
        'amount_withdrawn', p_amount,
        'remaining_balance', v_new_balance
    );
END;
$$;

-- 4. STORED PROCEDURE: fund_contract_escrow (Depósito em Garantia para Iniciar Contrato)
CREATE OR REPLACE FUNCTION public.fund_contract_escrow(
    p_contract_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_caller_id UUID;
    v_client_id UUID;
    v_total_amount NUMERIC(10,2);
    v_job_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Não autenticado';
    END IF;

    SELECT client_id, total_amount, job_id
    INTO v_client_id, v_total_amount, v_job_id
    FROM public.contracts
    WHERE id = p_contract_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Contrato não encontrado';
    END IF;

    IF v_caller_id != v_client_id THEN
        RAISE EXCEPTION 'Apenas o contratante pode financiar o escrow deste contrato';
    END IF;

    -- Atualizar status do contrato para active e escrow_amount
    UPDATE public.contracts
    SET 
        status = 'active',
        escrow_amount = v_total_amount,
        updated_at = NOW()
    WHERE id = p_contract_id;

    -- Atualizar status dos marcos para funded_in_escrow
    UPDATE public.milestones
    SET 
        status = 'funded_in_escrow',
        updated_at = NOW()
    WHERE contract_id = p_contract_id;

    -- Atualizar vaga para in_progress
    UPDATE public.jobs
    SET 
        status = 'in_progress',
        updated_at = NOW()
    WHERE id = v_job_id;

    -- Registrar transação de depósito
    INSERT INTO public.transactions (
        user_id,
        contract_id,
        type,
        amount,
        status
    ) VALUES (
        v_client_id,
        p_contract_id,
        'escrow_hold',
        v_total_amount,
        'completed'
    );

    RETURN jsonb_build_object(
        'success', true,
        'contract_id', p_contract_id,
        'status', 'active',
        'escrow_amount', v_total_amount
    );
END;
$$;

-- 5. NOTIFICAR POSTGREST
NOTIFY pgrst, 'reload schema';
