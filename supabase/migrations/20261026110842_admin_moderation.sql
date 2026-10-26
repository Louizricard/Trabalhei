-- Painel de administração: administradores, denúncias, suspensão de contas e
-- remoção de vagas. Toda ação de moderação passa por funções que conferem se
-- quem chama é administrador e ficam registradas em moderation_actions.

-- Administradores ficam fora do perfil público e só o banco altera a lista.
create table public.admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.admins enable row level security;
create policy admins_select_own on public.admins
  for select to authenticated using (user_id = (select auth.uid()));
revoke insert, update, delete on public.admins from anon, authenticated;

create function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.admins where user_id = (select auth.uid()))
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

-- Conta suspensa: some das buscas e do acesso de visitantes, e o login é
-- bloqueado no Auth (banned_until). O motivo fica só no registro de ações.
alter table public.profiles add column suspended_at timestamptz;
grant select (suspended_at) on public.profiles to anon, authenticated;

alter policy profiles_select_anon on public.profiles
  using (deleted_at is null and suspended_at is null);

-- Denúncias de vagas e perfis, feitas por usuários logados.
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  target_type text not null check (target_type in ('job', 'profile')),
  target_id uuid not null,
  reason text not null check (reason in ('spam', 'fraud', 'offensive', 'fake', 'off_platform_payment', 'other')),
  details text check (details is null or char_length(details) <= 1000),
  status text not null default 'open' check (status in ('open', 'resolved', 'dismissed')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references auth.users (id) on delete set null
);
create index reports_status_idx on public.reports (status, created_at desc);
-- Uma denúncia aberta por pessoa para o mesmo alvo.
create unique index reports_one_open_per_target
  on public.reports (reporter_id, target_type, target_id) where status = 'open';

alter table public.reports enable row level security;
create policy reports_insert_own on public.reports
  for insert to authenticated
  with check (reporter_id = (select auth.uid()) and status = 'open');
create policy reports_select_own on public.reports
  for select to authenticated
  using (reporter_id = (select auth.uid()));
revoke update, delete on public.reports from anon, authenticated;
revoke all on public.reports from anon;

-- Registro de tudo que os administradores fizeram.
create table public.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references auth.users (id) on delete set null,
  action text not null,
  target_type text not null,
  target_id uuid not null,
  reason text,
  created_at timestamptz not null default now()
);
alter table public.moderation_actions enable row level security;
revoke all on public.moderation_actions from anon, authenticated;

create function public.require_admin()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then raise exception 'FORBIDDEN'; end if;
end;
$$;
revoke all on function public.require_admin() from public, anon, authenticated;

-- Resumo do painel.
create function public.admin_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  return jsonb_build_object(
    'users', (select count(*) from public.profiles where deleted_at is null),
    'suspended', (select count(*) from public.profiles where suspended_at is not null),
    'open_jobs', (select count(*) from public.jobs where status = 'open'),
    'open_reports', (select count(*) from public.reports where status = 'open')
  );
end;
$$;

-- Denúncias com o nome de quem denunciou e o título/nome do alvo.
create function public.admin_list_reports(p_status text default 'open')
returns table (
  id uuid, target_type text, target_id uuid, target_label text, reason text,
  details text, status text, created_at timestamptz, reporter_id uuid,
  reporter_name text, reports_on_target bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  return query
  select r.id, r.target_type, r.target_id,
    case r.target_type
      when 'job' then (select j.title from public.jobs j where j.id = r.target_id)
      else (select p.full_name from public.profiles p where p.id = r.target_id)
    end,
    r.reason, r.details, r.status, r.created_at, r.reporter_id, rp.full_name,
    (select count(*) from public.reports o
      where o.target_type = r.target_type and o.target_id = r.target_id and o.status = 'open')
  from public.reports r
  left join public.profiles rp on rp.id = r.reporter_id
  where r.status = p_status
  order by r.created_at desc
  limit 200;
end;
$$;

create function public.admin_resolve_report(p_report_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  if p_status not in ('resolved', 'dismissed') then raise exception 'INVALID_STATUS'; end if;
  update public.reports
    set status = p_status, resolved_at = now(), resolved_by = auth.uid()
    where id = p_report_id and status = 'open';
  if not found then raise exception 'REPORT_NOT_FOUND'; end if;
  insert into public.moderation_actions (admin_id, action, target_type, target_id)
    values (auth.uid(), 'report_' || p_status, 'report', p_report_id);
end;
$$;

-- Busca de usuários por nome ou e-mail (o e-mail só aparece para admins).
create function public.admin_search_users(p_query text default '')
returns table (
  id uuid, full_name text, email text, role text, plan text,
  created_at timestamptz, last_sign_in_at timestamptz, suspended_at timestamptz,
  is_admin boolean, open_reports bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_term text := '%' || coalesce(trim(p_query), '') || '%';
begin
  perform public.require_admin();
  return query
  select p.id, p.full_name, u.email::text, p.role, p.plan, p.created_at,
    u.last_sign_in_at, p.suspended_at,
    exists (select 1 from public.admins a where a.user_id = p.id),
    (select count(*) from public.reports r
      where r.target_type = 'profile' and r.target_id = p.id and r.status = 'open')
  from public.profiles p
  join auth.users u on u.id = p.id
  where p.deleted_at is null
    and (p.full_name ilike v_term or u.email ilike v_term)
  order by p.suspended_at desc nulls last, p.created_at desc
  limit 100;
end;
$$;

-- Suspende a conta: bloqueia o login, encerra as sessões, tira o perfil das
-- buscas e cancela as vagas abertas da pessoa.
create function public.admin_suspend_user(p_user_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  if p_user_id = auth.uid() then raise exception 'CANNOT_MODERATE_SELF'; end if;
  if exists (select 1 from public.admins where user_id = p_user_id) then
    raise exception 'CANNOT_MODERATE_ADMIN';
  end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'REASON_REQUIRED'; end if;

  update public.profiles set suspended_at = now()
    where id = p_user_id and suspended_at is null;
  if not found then raise exception 'USER_NOT_FOUND_OR_SUSPENDED'; end if;

  update auth.users set banned_until = 'infinity' where id = p_user_id;
  delete from auth.sessions where user_id = p_user_id;

  update public.proposals set status = 'rejected'
    where status in ('pending', 'counter_offered')
      and job_id in (select j.id from public.jobs j where j.client_id = p_user_id and j.status = 'open');
  update public.jobs set status = 'cancelled' where client_id = p_user_id and status = 'open';

  update public.reports set status = 'resolved', resolved_at = now(), resolved_by = auth.uid()
    where target_type = 'profile' and target_id = p_user_id and status = 'open';

  insert into public.moderation_actions (admin_id, action, target_type, target_id, reason)
    values (auth.uid(), 'suspend_user', 'profile', p_user_id, trim(p_reason));

  perform public.notify(
    p_user_id, 'account_suspended', 'Sua conta foi suspensa',
    'Motivo: ' || trim(p_reason) || '. Se acha que foi um engano, responda ao suporte.',
    '{}'::jsonb
  );
end;
$$;

create function public.admin_unsuspend_user(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  update public.profiles set suspended_at = null
    where id = p_user_id and suspended_at is not null;
  if not found then raise exception 'USER_NOT_SUSPENDED'; end if;
  update auth.users set banned_until = null where id = p_user_id;
  insert into public.moderation_actions (admin_id, action, target_type, target_id)
    values (auth.uid(), 'unsuspend_user', 'profile', p_user_id);
  perform public.notify(
    p_user_id, 'account_restored', 'Sua conta foi reativada',
    'Você já pode entrar de novo no Trabalhei.', '{}'::jsonb
  );
end;
$$;

-- Vagas recentes de qualquer status, para moderar.
create function public.admin_list_jobs(p_query text default '')
returns table (
  id uuid, title text, status text, category text, client_id uuid,
  client_name text, created_at timestamptz, open_reports bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_term text := '%' || coalesce(trim(p_query), '') || '%';
begin
  perform public.require_admin();
  return query
  select j.id, j.title, j.status, j.category, j.client_id, p.full_name, j.created_at,
    (select count(*) from public.reports r
      where r.target_type = 'job' and r.target_id = j.id and r.status = 'open') as open_reports
  from public.jobs j
  left join public.profiles p on p.id = j.client_id
  where j.title ilike v_term or p.full_name ilike v_term
  order by open_reports desc, j.created_at desc
  limit 100;
end;
$$;

-- Remove a vaga do mural (cancela e recusa as propostas pendentes).
create function public.admin_remove_job(p_job_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job public.jobs;
begin
  perform public.require_admin();
  if coalesce(trim(p_reason), '') = '' then raise exception 'REASON_REQUIRED'; end if;
  update public.jobs set status = 'cancelled'
    where id = p_job_id and status = 'open'
    returning * into v_job;
  if not found then raise exception 'JOB_NOT_OPEN'; end if;
  update public.proposals set status = 'rejected'
    where job_id = p_job_id and status in ('pending', 'counter_offered');
  update public.reports set status = 'resolved', resolved_at = now(), resolved_by = auth.uid()
    where target_type = 'job' and target_id = p_job_id and status = 'open';
  insert into public.moderation_actions (admin_id, action, target_type, target_id, reason)
    values (auth.uid(), 'remove_job', 'job', p_job_id, trim(p_reason));
  perform public.notify(
    v_job.client_id, 'job_removed', 'Sua vaga foi removida do mural',
    '"' || v_job.title || '" foi removida pela moderação. Motivo: ' || trim(p_reason) || '.',
    jsonb_build_object('job_id', v_job.id, 'route', '/jobs/' || v_job.id)
  );
end;
$$;

revoke all on function
  public.admin_overview(),
  public.admin_list_reports(text),
  public.admin_resolve_report(uuid, text),
  public.admin_search_users(text),
  public.admin_suspend_user(uuid, text),
  public.admin_unsuspend_user(uuid),
  public.admin_list_jobs(text),
  public.admin_remove_job(uuid, text)
from public, anon;
grant execute on function
  public.admin_overview(),
  public.admin_list_reports(text),
  public.admin_resolve_report(uuid, text),
  public.admin_search_users(text),
  public.admin_suspend_user(uuid, text),
  public.admin_unsuspend_user(uuid),
  public.admin_list_jobs(text),
  public.admin_remove_job(uuid, text)
to authenticated;
