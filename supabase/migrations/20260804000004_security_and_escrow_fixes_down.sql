-- ============================================================================
-- Rollback Migration: 20260804000004_security_and_escrow_fixes_down.sql
-- Description: Reversão de procedures de escrow, saques e policies de transações
-- ============================================================================

DROP FUNCTION IF EXISTS public.fund_contract_escrow(UUID);
DROP FUNCTION IF EXISTS public.request_pix_payout(NUMERIC, TEXT);
DROP FUNCTION IF EXISTS public.release_escrow_milestone(UUID);

DROP POLICY IF EXISTS "Users can read own transactions" ON public.transactions;

NOTIFY pgrst, 'reload schema';
