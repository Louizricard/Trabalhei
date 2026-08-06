-- ============================================================================
-- Rollback Migration: 20260806000005_sprint1_rls_security_hardening_down.sql
-- ============================================================================

-- 1. Desfazer triggers e functions
DROP TRIGGER IF EXISTS trg_protect_profile_sensitive_fields ON public.profiles;
DROP FUNCTION IF EXISTS public.trg_fn_protect_profile_sensitive_fields();

DROP TRIGGER IF EXISTS trg_validate_milestone_transition ON public.milestones;
DROP FUNCTION IF EXISTS public.trg_fn_validate_milestone_transition();

-- 2. Restaurar grants de transactions
GRANT INSERT, UPDATE, DELETE ON public.transactions TO authenticated;

-- 3. Notificar PostgREST
NOTIFY pgrst, 'reload schema';
