-- ============================================================================
-- Migration: 20260807000003_db_audit_hardening_indexes_and_realtime.sql
-- Description: Auditoria completa do banco de dados:
--   1. Índices em chaves estrangeiras faltantes (otimização de performance)
--   2. Políticas RLS para freelancer_skills e job_skills
--   3. Proteção de search_path em funções SECURITY DEFINER
--   4. Revogação de privilégios públicos em funções internas de triggers
--   5. Inclusão de tabelas essenciais na publicação supabase_realtime
-- ============================================================================

-- 1. Índices de performance para foreign keys
CREATE INDEX IF NOT EXISTS idx_contracts_freelancer_id ON public.contracts(freelancer_id);
CREATE INDEX IF NOT EXISTS idx_contracts_proposal_id ON public.contracts(proposal_id);
CREATE INDEX IF NOT EXISTS idx_conversations_contract_id ON public.conversations(contract_id);
CREATE INDEX IF NOT EXISTS idx_conversations_job_id ON public.conversations(job_id);
CREATE INDEX IF NOT EXISTS idx_conversations_participant_b ON public.conversations(participant_b);
CREATE INDEX IF NOT EXISTS idx_dispute_events_user_id ON public.dispute_events(user_id);
CREATE INDEX IF NOT EXISTS idx_disputes_opened_by ON public.disputes(opened_by);
CREATE INDEX IF NOT EXISTS idx_freelancer_skills_skill_id ON public.freelancer_skills(skill_id);
CREATE INDEX IF NOT EXISTS idx_job_skills_skill_id ON public.job_skills(skill_id);
CREATE INDEX IF NOT EXISTS idx_jobs_category_id ON public.jobs(category_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_milestone_revisions_requested_by ON public.milestone_revisions(requested_by);
CREATE INDEX IF NOT EXISTS idx_proposal_counter_offers_offered_by ON public.proposal_counter_offers(offered_by);
CREATE INDEX IF NOT EXISTS idx_proposals_counter_by_user_id ON public.proposals(counter_by_user_id);
CREATE INDEX IF NOT EXISTS idx_reviews_contract_id ON public.reviews(contract_id);
CREATE INDEX IF NOT EXISTS idx_reviews_reviewer_id ON public.reviews(reviewer_id);

-- 2. Políticas RLS em tabelas auxiliares
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polname = 'Freelancer skills viewable by everyone' AND polrelid = 'public.freelancer_skills'::regclass) THEN
        CREATE POLICY "Freelancer skills viewable by everyone" ON public.freelancer_skills FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polname = 'Freelancers can manage own skills' AND polrelid = 'public.freelancer_skills'::regclass) THEN
        CREATE POLICY "Freelancers can manage own skills" ON public.freelancer_skills FOR ALL USING ((SELECT auth.uid()) = freelancer_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polname = 'Job skills viewable by everyone' AND polrelid = 'public.job_skills'::regclass) THEN
        CREATE POLICY "Job skills viewable by everyone" ON public.job_skills FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polname = 'Clients can manage job skills' AND polrelid = 'public.job_skills'::regclass) THEN
        CREATE POLICY "Clients can manage job skills" ON public.job_skills FOR ALL USING (EXISTS (SELECT 1 FROM public.jobs WHERE id = job_skills.job_id AND client_id = (SELECT auth.uid())));
    END IF;
END $$;

-- 3. Hardening de search_path
ALTER FUNCTION public.sync_proposal_fields() SET search_path = public, pg_temp;
ALTER FUNCTION public.request_pix_payout(numeric, text) SET search_path = public, pg_temp;
ALTER FUNCTION public.handle_new_review() SET search_path = public, pg_temp;
ALTER FUNCTION public.handle_dispute_opened_trigger() SET search_path = public, pg_temp;
ALTER FUNCTION public.handle_new_user() SET search_path = public, pg_temp;
ALTER FUNCTION public.trg_fn_protect_profile_sensitive_fields() SET search_path = public, pg_temp;
ALTER FUNCTION public.release_escrow_milestone(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.confirm_escrow_deposit(text, numeric, text, jsonb, uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.accept_proposal_and_create_contract(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.trg_fn_validate_milestone_transition() SET search_path = public, pg_temp;

-- 4. Permissões de execução estritas
REVOKE EXECUTE ON FUNCTION public.accept_proposal_and_create_contract(uuid) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.accept_proposal_and_create_contract(uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.confirm_escrow_deposit(text, numeric, text, jsonb, uuid) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.confirm_escrow_deposit(text, numeric, text, jsonb, uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.release_escrow_milestone(uuid) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.release_escrow_milestone(uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.request_pix_payout(numeric, text) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.request_pix_payout(numeric, text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.create_notification(uuid, text, text, text, jsonb) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.create_notification(uuid, text, text, text, jsonb) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.mark_all_notifications_as_read() FROM anon, public;
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_as_read() TO authenticated, service_role;

-- Revogar execução direta em funções internas de triggers
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_new_review() FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_dispute_opened_trigger() FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_fn_notify_on_contract_status_change() FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_fn_notify_on_milestone_status_change() FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_fn_notify_on_new_message() FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_fn_notify_on_new_proposal() FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_fn_protect_profile_sensitive_fields() FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_fn_validate_milestone_transition() FROM public, anon, authenticated;

-- 5. Realtime Publication
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'contracts') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.contracts;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'disputes') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.disputes;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'dispute_events') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.dispute_events;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'proposal_counter_offers') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.proposal_counter_offers;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'milestone_revisions') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.milestone_revisions;
    END IF;
END $$;

NOTIFY pgrst, 'reload schema';
