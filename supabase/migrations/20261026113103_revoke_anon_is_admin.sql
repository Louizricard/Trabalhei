-- O Supabase concede EXECUTE a anon em funções novas por padrão; visitantes
-- não precisam saber se são administradores nem testar alertas.
revoke execute on function public.is_admin() from anon;
revoke execute on function public.job_matches_alert(public.jobs, public.job_alerts) from anon;
