-- Desfaz 20261026110913_job_alerts.
drop trigger if exists jobs_notify_alerts on public.jobs;
drop function if exists public.notify_job_alerts();
drop function if exists public.job_matches_alert(public.jobs, public.job_alerts);
drop trigger if exists job_alerts_limit_trg on public.job_alerts;
drop function if exists public.job_alerts_limit();
drop table if exists public.job_alerts;
