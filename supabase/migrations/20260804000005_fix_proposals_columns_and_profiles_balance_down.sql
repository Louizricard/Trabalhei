-- ============================================================================
-- Rollback: 20260804000005_fix_proposals_columns_and_profiles_balance_down.sql
-- ============================================================================

DROP TRIGGER IF EXISTS trigger_sync_proposal_fields ON public.proposals;
DROP FUNCTION IF EXISTS public.sync_proposal_fields();

ALTER TABLE public.profiles DROP COLUMN IF EXISTS escrow_balance;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS wallet_balance;
