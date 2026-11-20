-- Desfaz 20261120145320_storage_cleanup_schedule.
-- A extensão pg_cron fica instalada (outros agendamentos podem usá-la).

select cron.unschedule('storage-cleanup')
  where exists (select 1 from cron.job where jobname = 'storage-cleanup');
drop function if exists public.run_storage_cleanup();
drop function if exists public.storage_cleanup_token_ok(text);
delete from vault.secrets where name in ('storage_cleanup_token', 'storage_cleanup_url');
