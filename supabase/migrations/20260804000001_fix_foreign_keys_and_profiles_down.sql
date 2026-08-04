-- ============================================================================
-- Migration: 20260804000001_fix_foreign_keys_and_profiles_down.sql
-- Description: Rollback foreign key fixes
-- ============================================================================

ALTER TABLE IF EXISTS public.jobs 
    DROP CONSTRAINT IF EXISTS jobs_client_id_fkey;

ALTER TABLE IF EXISTS public.proposals 
    DROP CONSTRAINT IF EXISTS proposals_freelancer_id_fkey;

NOTIFY pgrst, 'reload schema';
