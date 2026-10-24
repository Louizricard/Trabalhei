-- Rollback: volta as funções auxiliares ao search_path padrão da sessão.
alter function public.free_monthly_proposal_limit() reset search_path;
alter function public.touch_updated_at() reset search_path;
