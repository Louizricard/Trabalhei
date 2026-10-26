-- Alertas de vagas: a pessoa salva um filtro do mural e recebe uma
-- notificação (no app, por e-mail e push) quando sai uma vaga compatível.
create table public.job_alerts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 60),
  query text check (query is null or char_length(query) <= 80),
  category text check (category is null or char_length(category) <= 40),
  experience_level text check (experience_level is null or experience_level in ('junior', 'pleno', 'senior')),
  contract_type text check (contract_type is null or contract_type in ('fixed', 'hourly')),
  min_budget numeric check (min_budget is null or min_budget >= 0),
  max_deadline_days integer check (max_deadline_days is null or max_deadline_days > 0),
  urgent_only boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  last_matched_at timestamptz
);
create index job_alerts_active_idx on public.job_alerts (is_active) where is_active;
create index job_alerts_user_idx on public.job_alerts (user_id);

alter table public.job_alerts enable row level security;
create policy job_alerts_own on public.job_alerts
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
revoke all on public.job_alerts from anon;

-- Até 10 alertas por pessoa.
create function public.job_alerts_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select count(*) from public.job_alerts where user_id = new.user_id) >= 10 then
    raise exception 'ALERT_LIMIT_REACHED';
  end if;
  return new;
end;
$$;
revoke all on function public.job_alerts_limit() from public, anon, authenticated;
create trigger job_alerts_limit_trg before insert on public.job_alerts
  for each row execute function public.job_alerts_limit();

-- A vaga atende ao alerta? Campos vazios do alerta aceitam qualquer valor.
create function public.job_matches_alert(j public.jobs, a public.job_alerts)
returns boolean
language sql
stable
set search_path = ''
as $$
  select
    (a.query is null or trim(a.query) = ''
      or j.title ilike '%' || trim(a.query) || '%'
      or j.description ilike '%' || trim(a.query) || '%'
      or exists (select 1 from unnest(j.skills_required) s where s ilike '%' || trim(a.query) || '%'))
    and (a.category is null or lower(j.category) = lower(a.category))
    and (a.experience_level is null or j.experience_level in (a.experience_level, 'all'))
    and (a.contract_type is null or j.contract_type = a.contract_type)
    and (a.min_budget is null or j.budget_max >= a.min_budget)
    and (a.max_deadline_days is null or j.deadline_days <= a.max_deadline_days)
    and (not a.urgent_only or j.is_urgent)
$$;

create function public.notify_job_alerts()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  a public.job_alerts;
begin
  if new.status <> 'open' then return null; end if;
  for a in
    select al.* from public.job_alerts al
    join public.profiles p on p.id = al.user_id
    where al.is_active
      and al.user_id <> new.client_id
      and p.deleted_at is null and p.suspended_at is null
      and public.job_matches_alert(new, al)
  loop
    perform public.notify(
      a.user_id, 'job_alert', 'Nova vaga para o alerta "' || a.name || '"',
      new.title,
      jsonb_build_object('job_id', new.id, 'alert_id', a.id, 'route', '/jobs/' || new.id)
    );
    update public.job_alerts set last_matched_at = now() where id = a.id;
  end loop;
  return null;
end;
$$;
revoke all on function public.notify_job_alerts() from public, anon, authenticated;

create trigger jobs_notify_alerts
  after insert on public.jobs
  for each row execute function public.notify_job_alerts();
