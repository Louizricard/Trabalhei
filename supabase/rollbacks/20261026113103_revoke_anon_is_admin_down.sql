-- Desfaz 20261026113103_revoke_anon_is_admin.
grant execute on function public.is_admin() to anon;
grant execute on function public.job_matches_alert(public.jobs, public.job_alerts) to anon;
