-- ============================================================================
-- Migration: 20260806000003_add_proposal_counter_offer_fields.sql
-- Description: Adiciona colunas de contraproposta na tabela proposals e atualiza a view v_job_proposals
-- ============================================================================

-- 1. Alterar tabela proposals
ALTER TABLE public.proposals ADD COLUMN IF NOT EXISTS counter_price NUMERIC(10,2);
ALTER TABLE public.proposals ADD COLUMN IF NOT EXISTS counter_estimated_days INTEGER;
ALTER TABLE public.proposals ADD COLUMN IF NOT EXISTS counter_message TEXT;
ALTER TABLE public.proposals ADD COLUMN IF NOT EXISTS counter_by_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.proposals ADD COLUMN IF NOT EXISTS counter_created_at TIMESTAMPTZ;

-- 2. Recriar View v_job_proposals
DROP VIEW IF EXISTS public.v_job_proposals CASCADE;

CREATE VIEW public.v_job_proposals WITH (security_invoker = true) AS
SELECT
    p.id,
    p.job_id,
    p.freelancer_id,
    p.bid_amount,
    COALESCE(p.bid_amount, p.amount) AS amount,
    p.estimated_days,
    p.cover_letter,
    COALESCE(p.cover_letter, p.message) AS message,
    p.status,
    COALESCE(p.proposed_milestones, '[]'::jsonb) AS proposed_milestones,
    COALESCE(p.screening_answers, '[]'::jsonb) AS screening_answers,
    p.counter_price,
    p.counter_estimated_days,
    p.counter_message,
    p.counter_by_user_id,
    p.counter_created_at,
    p.created_at,
    p.updated_at,
    COALESCE(prof.full_name, 'Freelancer') AS freelancer_name,
    prof.avatar_url AS freelancer_avatar_url,
    COALESCE(prof.rating, 5.0) AS freelancer_rating,
    COALESCE(prof.skills, '{}'::text[]) AS freelancer_skills,
    prof.bio AS freelancer_bio,
    j.title AS job_title,
    j.client_id,
    j.category AS job_category,
    j.budget_min AS job_budget_min,
    j.budget_max AS job_budget_max
FROM public.proposals p
JOIN public.jobs j ON j.id = p.job_id
LEFT JOIN public.profiles prof ON prof.id = p.freelancer_id;

GRANT SELECT ON public.v_job_proposals TO authenticated, anon, service_role;

NOTIFY pgrst, 'reload schema';
