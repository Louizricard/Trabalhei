-- Desfaz 20261026110842_admin_moderation. Antes, reative as contas suspensas
-- (admin_unsuspend_user) para não deixar logins bloqueados no Auth.
drop function if exists public.admin_remove_job(uuid, text);
drop function if exists public.admin_list_jobs(text);
drop function if exists public.admin_unsuspend_user(uuid);
drop function if exists public.admin_suspend_user(uuid, text);
drop function if exists public.admin_search_users(text);
drop function if exists public.admin_resolve_report(uuid, text);
drop function if exists public.admin_list_reports(text);
drop function if exists public.admin_overview();
drop function if exists public.require_admin();
drop table if exists public.moderation_actions;
drop table if exists public.reports;
alter policy profiles_select_anon on public.profiles using (deleted_at is null);
alter table public.profiles drop column if exists suspended_at;
drop function if exists public.is_admin();
drop table if exists public.admins;
