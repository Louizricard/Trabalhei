-- ============================================================================
-- Migration: 20260807000002_fix_proposals_status_check_constraint.sql
-- Description: Adiciona o valor 'counter_offered' à check constraint proposals_status_check
-- ============================================================================

ALTER TABLE public.proposals DROP CONSTRAINT IF EXISTS proposals_status_check;

ALTER TABLE public.proposals ADD CONSTRAINT proposals_status_check 
    CHECK (status IN ('pending', 'accepted', 'rejected', 'withdrawn', 'counter_offered'));

NOTIFY pgrst, 'reload schema';
