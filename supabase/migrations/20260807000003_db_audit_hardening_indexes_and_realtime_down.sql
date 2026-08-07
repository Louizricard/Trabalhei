-- ============================================================================
-- Migration: 20260807000003_db_audit_hardening_indexes_and_realtime_down.sql
-- Description: Rollback da auditoria e hardening
-- ============================================================================

DROP INDEX IF EXISTS public.idx_contracts_freelancer_id;
DROP INDEX IF EXISTS public.idx_contracts_proposal_id;
DROP INDEX IF EXISTS public.idx_conversations_contract_id;
DROP INDEX IF EXISTS public.idx_conversations_job_id;
DROP INDEX IF EXISTS public.idx_conversations_participant_b;
DROP INDEX IF EXISTS public.idx_dispute_events_user_id;
DROP INDEX IF EXISTS public.idx_disputes_opened_by;
DROP INDEX IF EXISTS public.idx_freelancer_skills_skill_id;
DROP INDEX IF EXISTS public.idx_job_skills_skill_id;
DROP INDEX IF EXISTS public.idx_jobs_category_id;
DROP INDEX IF EXISTS public.idx_messages_sender_id;
DROP INDEX IF EXISTS public.idx_milestone_revisions_requested_by;
DROP INDEX IF EXISTS public.idx_proposal_counter_offers_offered_by;
DROP INDEX IF EXISTS public.idx_proposals_counter_by_user_id;
DROP INDEX IF EXISTS public.idx_reviews_contract_id;
DROP INDEX IF EXISTS public.idx_reviews_reviewer_id;

DROP POLICY IF EXISTS "Freelancer skills viewable by everyone" ON public.freelancer_skills;
DROP POLICY IF EXISTS "Freelancers can manage own skills" ON public.freelancer_skills;
DROP POLICY IF EXISTS "Job skills viewable by everyone" ON public.job_skills;
DROP POLICY IF EXISTS "Clients can manage job skills" ON public.job_skills;

NOTIFY pgrst, 'reload schema';
