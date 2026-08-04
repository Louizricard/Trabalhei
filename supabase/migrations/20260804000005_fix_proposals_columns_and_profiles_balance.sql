-- ============================================================================
-- Migration: 20260804000005_fix_proposals_columns_and_profiles_balance.sql
-- Description: 
--   1. Corrige a tabela proposals: remove NOT NULL da coluna amount, sincroniza amount e bid_amount, message e cover_letter via trigger.
--   2. Adiciona colunas wallet_balance e escrow_balance na tabela profiles.
-- ============================================================================

-- 1. PROPOSALS: Permitir amount nulo ou preenchimento via bid_amount
ALTER TABLE public.proposals ALTER COLUMN amount DROP NOT NULL;

-- Sincronizar dados existentes em proposals
UPDATE public.proposals 
SET amount = COALESCE(amount, bid_amount),
    bid_amount = COALESCE(bid_amount, amount),
    cover_letter = COALESCE(cover_letter, message),
    message = COALESCE(message, cover_letter);

-- Criar trigger para manter amount/bid_amount e message/cover_letter em sincronia em novos inserts/updates
CREATE OR REPLACE FUNCTION public.sync_proposal_fields()
RETURNS TRIGGER AS $$
BEGIN
    NEW.amount := COALESCE(NEW.amount, NEW.bid_amount);
    NEW.bid_amount := COALESCE(NEW.bid_amount, NEW.amount);
    NEW.cover_letter := COALESCE(NEW.cover_letter, NEW.message);
    NEW.message := COALESCE(NEW.message, NEW.cover_letter);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_sync_proposal_fields ON public.proposals;
CREATE TRIGGER trigger_sync_proposal_fields
BEFORE INSERT OR UPDATE ON public.proposals
FOR EACH ROW
EXECUTE FUNCTION public.sync_proposal_fields();

-- 2. PROFILES: Adicionar colunas wallet_balance e escrow_balance se não existirem
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS wallet_balance NUMERIC(10,2) NOT NULL DEFAULT 0.00;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS escrow_balance NUMERIC(10,2) NOT NULL DEFAULT 0.00;

-- Sincronizar valores nulos existentes
UPDATE public.profiles
SET wallet_balance = COALESCE(wallet_balance, 0.00),
    escrow_balance = COALESCE(escrow_balance, 0.00)
WHERE wallet_balance IS NULL OR escrow_balance IS NULL;
