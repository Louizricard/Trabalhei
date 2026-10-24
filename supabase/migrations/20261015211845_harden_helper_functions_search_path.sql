-- Fixa o search_path das funções auxiliares (advisor de segurança do Supabase).
-- Em bancos novos é redundante: a migration inicial já cria as funções assim.
alter function public.free_monthly_proposal_limit() set search_path = public;
alter function public.touch_updated_at() set search_path = public;
