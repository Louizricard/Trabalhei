-- Rollback: Drop user_push_tokens table, triggers, and functions
-- Down Migration

DROP TRIGGER IF EXISTS trg_user_push_tokens_updated_at ON public.user_push_tokens;
DROP FUNCTION IF EXISTS public.handle_user_push_tokens_updated_at();
DROP TABLE IF EXISTS public.user_push_tokens CASCADE;
