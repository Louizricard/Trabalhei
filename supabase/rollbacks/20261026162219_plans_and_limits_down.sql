-- Desfaz 20261026162219_plans_and_limits. Antes, volte o app para a versão
-- anterior (ele lê billing_products e platform_settings). As funções
-- proposal_quota, submit_proposal, admin_remove_job e admin_suspend_user
-- voltam às definições das migrações 20261015211818 e 20261026110842
-- (reaplique-as a partir desses arquivos).
drop function if exists public.proposal_stats(integer);
drop function if exists public.freelancer_clients();
drop table if exists public.client_notes;
drop trigger if exists proposal_templates_limit_trg on public.proposal_templates;
drop function if exists public.proposal_templates_limit();
drop table if exists public.proposal_templates;
drop function if exists public.counted_proposals(uuid, timestamptz);
alter table public.jobs drop column if exists moderated_at;
create or replace function public.free_monthly_proposal_limit()
returns integer language sql immutable set search_path to 'public' as $$ select 5 $$;
drop function if exists public.settings();
drop table if exists public.platform_settings;
drop table if exists public.billing_products;
