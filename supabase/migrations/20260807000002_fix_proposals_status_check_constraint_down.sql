-- ============================================================================
-- Migration: 20260807000002_fix_proposals_status_check_constraint_down.sql
-- Description: Rollback do valor 'counter_offered' na check constraint proposals_status_check
-- ============================================================================

ALTER TABLE public.proposals DROP CONSTRAINT IF EXISTS proposals_status_check;

ALTER TABLE public.proposals ADD CONSTRAINT proposals_status_check 
    CHECK (status IN ('pending', 'accepted', 'rejected', 'withdrawn'));

NOTIFY pgrst, 'reload schema';
