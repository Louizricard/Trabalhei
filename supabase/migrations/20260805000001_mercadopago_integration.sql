-- ============================================================================
-- Migration: 20260805000001_mercadopago_integration.sql
-- Description: Campos de Gateway (Mercado Pago), Stored Procedures atômicas para
--              depósito em Escrow, confirmação via Webhook e Payout Pix.
-- ============================================================================

-- 1. ADICIONAR COLUNAS DE GATEWAY NA TABELA TRANSACTIONS
ALTER TABLE public.transactions
    ADD COLUMN IF NOT EXISTS gateway_provider TEXT DEFAULT 'mercadopago',
    ADD COLUMN IF NOT EXISTS gateway_status TEXT,
    ADD COLUMN IF NOT EXISTS qr_code TEXT,
    ADD COLUMN IF NOT EXISTS qr_code_base64 TEXT,
    ADD COLUMN IF NOT EXISTS payment_method TEXT,
    ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

-- Índice para buscas rápidas pelo ID do pagamento do gateway
CREATE INDEX IF NOT EXISTS idx_transactions_gateway_ref ON public.transactions(gateway_ref);
CREATE INDEX IF NOT EXISTS idx_transactions_contract_id ON public.transactions(contract_id);

-- 2. STORED PROCEDURE: confirm_escrow_deposit (Confirmação segura de pagamento e ativação do Escrow)
CREATE OR REPLACE FUNCTION public.confirm_escrow_deposit(
    p_gateway_ref TEXT,
    p_paid_amount NUMERIC,
    p_gateway_status TEXT DEFAULT 'approved',
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_tx RECORD;
    v_contract_id UUID;
    v_job_id UUID;
    v_client_id UUID;
    v_freelancer_id UUID;
    v_conv_id UUID;
    v_existing_conv RECORD;
BEGIN
    IF p_gateway_ref IS NULL OR TRIM(p_gateway_ref) = '' THEN
        RAISE EXCEPTION 'ID de referência do gateway é obrigatório.';
    END IF;

    -- 1. Localizar e bloquear a transação (Lock FOR UPDATE para evitar concorrência)
    SELECT *
    INTO v_tx
    FROM public.transactions
    WHERE gateway_ref = p_gateway_ref
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transação com gateway_ref % não encontrada.', p_gateway_ref;
    END IF;

    -- Se já foi completada anteriormente, retorna sucesso idempotente
    IF v_tx.status = 'completed' THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'Transação já confirmada anteriormente (Idempotente).',
            'transaction_id', v_tx.id,
            'contract_id', v_tx.contract_id
        );
    END IF;

    -- 2. Atualizar o status da transação
    UPDATE public.transactions
    SET 
        status = 'completed',
        gateway_status = p_gateway_status,
        metadata = COALESCE(metadata, '{}'::jsonb) || p_metadata,
        amount = COALESCE(p_paid_amount, amount)
    WHERE id = v_tx.id;

    v_contract_id := v_tx.contract_id;

    -- 3. Se houver contrato associado, alimentar o Escrow
    IF v_contract_id IS NOT NULL THEN
        SELECT 
            id, job_id, client_id, freelancer_id, total_amount, escrow_amount
        INTO 
            v_contract_id, v_job_id, v_client_id, v_freelancer_id
        FROM public.contracts
        WHERE id = v_contract_id
        FOR UPDATE;

        IF FOUND THEN
            -- Creditar o valor pago no Escrow do contrato
            UPDATE public.contracts
            SET 
                escrow_amount = COALESCE(escrow_amount, 0) + COALESCE(p_paid_amount, v_tx.amount),
                status = 'active',
                updated_at = NOW()
            WHERE id = v_contract_id;

            -- Atualizar todos os marcos pendentes para 'funded_in_escrow'
            UPDATE public.milestones
            SET 
                status = 'funded_in_escrow'
            WHERE contract_id = v_contract_id
              AND status = 'pending';

            -- Atualizar status da vaga para 'in_progress'
            IF v_job_id IS NOT NULL THEN
                UPDATE public.jobs
                SET 
                    status = 'in_progress',
                    updated_at = NOW()
                WHERE id = v_job_id;
            END IF;

            -- 4. Notificar ambas as partes no Chat em tempo real
            SELECT id INTO v_conv_id
            FROM public.conversations
            WHERE contract_id = v_contract_id OR job_id = v_job_id
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
                    v_client_id,
                    '🎉 Pagamento de R$ ' || TO_CHAR(COALESCE(p_paid_amount, v_tx.amount), 'FM999G999D00') || ' confirmado via Mercado Pago! O valor está 100% retido em custódia segura (Escrow).',
                    'system_event',
                    false
                );

                UPDATE public.conversations
                SET last_message_at = NOW()
                WHERE id = v_conv_id;
            END IF;
        END IF;
    ELSE
        -- Depósito em carteira avulso (não vinculado a contrato específico)
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
        'amount_credited', COALESCE(p_paid_amount, v_tx.amount)
    );
END;
$$;

-- 3. STORED PROCEDURE: confirm_pix_payout (Confirmação ou estorno de saque Pix)
CREATE OR REPLACE FUNCTION public.confirm_pix_payout(
    p_gateway_ref TEXT,
    p_status TEXT, -- 'completed', 'failed', 'rejected'
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_tx RECORD;
BEGIN
    SELECT *
    INTO v_tx
    FROM public.transactions
    WHERE gateway_ref = p_gateway_ref
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transação de saque com gateway_ref % não encontrada.', p_gateway_ref;
    END IF;

    IF p_status = 'completed' OR p_status = 'approved' THEN
        UPDATE public.transactions
        SET 
            status = 'completed',
            gateway_status = p_status,
            metadata = COALESCE(metadata, '{}'::jsonb) || p_metadata
        WHERE id = v_tx.id;

        RETURN jsonb_build_object('success', true, 'status', 'completed');
    ELSIF p_status = 'failed' OR p_status = 'rejected' OR p_status = 'cancelled' THEN
        -- Estornar saldo debitado de volta para a carteira do freelancer
        UPDATE public.profiles
        SET 
            wallet_balance = COALESCE(wallet_balance, 0) + v_tx.amount,
            updated_at = NOW()
        WHERE id = v_tx.user_id;

        UPDATE public.transactions
        SET 
            status = 'failed',
            gateway_status = p_status,
            metadata = COALESCE(metadata, '{}'::jsonb) || p_metadata
        WHERE id = v_tx.id;

        RETURN jsonb_build_object('success', true, 'status', 'refunded_to_wallet');
    ELSE
        UPDATE public.transactions
        SET 
            gateway_status = p_status,
            metadata = COALESCE(metadata, '{}'::jsonb) || p_metadata
        WHERE id = v_tx.id;

        RETURN jsonb_build_object('success', true, 'status', p_status);
    END IF;
END;
$$;

-- 4. CONCEDER PERMISSÕES
GRANT EXECUTE ON FUNCTION public.confirm_escrow_deposit TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.confirm_pix_payout TO authenticated, service_role;
