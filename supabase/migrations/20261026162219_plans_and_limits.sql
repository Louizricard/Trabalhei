-- Planos e limites (out/2026). Tudo que muda com a estratégia de preços fica
-- em duas tabelas editáveis só pelo banco, lidas pelo app e pelas Edge
-- Functions: billing_products (preços) e platform_settings (limites).
-- Ver docs/monetizacao.md.

-- ---------------------------------------------------------------- Preços
create table public.billing_products (
  code text primary key check (code in ('pro_monthly', 'job_feature')),
  name text not null,
  price numeric(10, 2) not null check (price >= 0),
  period_days integer not null check (period_days > 0),
  active boolean not null default true,
  updated_at timestamptz not null default now()
);
insert into public.billing_products (code, name, price, period_days) values
  ('pro_monthly', 'Trabalhei Pro', 14.90, 30),
  ('job_feature', 'Destaque de projeto', 9.90, 7);

alter table public.billing_products enable row level security;
create policy billing_products_read on public.billing_products
  for select to anon, authenticated using (true);
revoke insert, update, delete on public.billing_products from anon, authenticated;

-- ---------------------------------------------------------------- Limites
create table public.platform_settings (
  id boolean primary key default true check (id),
  -- Propostas novas por mês (edições não contam).
  free_monthly_proposals integer not null default 10 check (free_monthly_proposals >= 0),
  pro_monthly_proposals integer not null default 50 check (pro_monthly_proposals >= 0),
  -- Teto por 24 h para todos: freia envio em massa mesmo no Pro.
  daily_proposals integer not null default 15 check (daily_proposals > 0),
  min_cover_letter_chars integer not null default 50 check (min_cover_letter_chars >= 0),
  -- Proposta pendente sem resposta do cliente por este prazo volta ao saldo.
  unanswered_refund_days integer not null default 14 check (unanswered_refund_days > 0),
  -- Vagas patrocinadas no topo do mural e tempo de cada rodada do rodízio.
  sponsored_slots integer not null default 2 check (sponsored_slots >= 0),
  sponsored_rotation_minutes integer not null default 60 check (sponsored_rotation_minutes > 0),
  -- Tamanho máximo por arquivo enviado no chat e nos anexos de vaga.
  free_file_mb integer not null default 10 check (free_file_mb > 0),
  pro_file_mb integer not null default 50 check (pro_file_mb > 0),
  max_proposal_templates integer not null default 20 check (max_proposal_templates >= 0),
  updated_at timestamptz not null default now()
);
insert into public.platform_settings default values;

alter table public.platform_settings enable row level security;
create policy platform_settings_read on public.platform_settings
  for select to anon, authenticated using (true);
revoke insert, update, delete on public.platform_settings from anon, authenticated;

create function public.settings()
returns public.platform_settings
language sql
stable
set search_path = ''
as $$ select * from public.platform_settings limit 1 $$;

-- Compatibilidade: funções antigas que liam o limite fixo.
create or replace function public.free_monthly_proposal_limit()
returns integer
language sql
stable
set search_path = ''
as $$ select free_monthly_proposals from public.platform_settings limit 1 $$;

-- ---------------------------------------------------------------- Moderação
-- Vaga removida pela moderação (ou de conta suspensa): propostas não contam.
alter table public.jobs add column moderated_at timestamptz;
grant select (moderated_at) on public.jobs to anon, authenticated;

create or replace function public.admin_remove_job(p_job_id uuid, p_reason text)
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
  update public.jobs set status = 'cancelled', moderated_at = now()
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

create or replace function public.admin_suspend_user(p_user_id uuid, p_reason text)
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
  update public.jobs set status = 'cancelled', moderated_at = now()
    where client_id = p_user_id and status = 'open';

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

-- ---------------------------------------------------------------- Cota
-- Propostas que contam no saldo do mês. Voltam ao saldo as enviadas para
-- vagas canceladas (pelo cliente ou pela moderação) e as que ficaram
-- pendentes, sem resposta do cliente, além de unanswered_refund_days.
create function public.counted_proposals(p_user uuid, p_since timestamptz)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
  from public.proposals p
  join public.jobs j on j.id = p.job_id
  where p.freelancer_id = p_user
    and p.created_at >= p_since
    and j.status <> 'cancelled'
    and j.moderated_at is null
    and not (
      p.status = 'pending'
      and p.counter_created_at is null
      and p.created_at < now() - make_interval(days => (select unanswered_refund_days from public.platform_settings limit 1))
    )
$$;
revoke all on function public.counted_proposals(uuid, timestamptz) from public, anon, authenticated;

create or replace function public.proposal_quota()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s public.platform_settings := public.settings();
  v_uid uuid := auth.uid();
  v_pro boolean := public.is_pro(v_uid);
  v_limit integer := case when v_pro then s.pro_monthly_proposals else s.free_monthly_proposals end;
  v_sent integer;
  v_used integer;
  v_today integer;
begin
  select count(*) into v_sent from public.proposals
    where freelancer_id = v_uid and created_at >= date_trunc('month', now());
  v_used := public.counted_proposals(v_uid, date_trunc('month', now()));
  select count(*) into v_today from public.proposals
    where freelancer_id = v_uid and created_at > now() - interval '24 hours';
  return jsonb_build_object(
    'is_pro', v_pro,
    'monthly_limit', v_limit,
    'used', v_used,
    'remaining', greatest(v_limit - v_used, 0),
    'refunded', greatest(v_sent - v_used, 0),
    'daily_limit', s.daily_proposals,
    'used_today', v_today,
    'min_cover_letter_chars', s.min_cover_letter_chars
  );
end;
$$;

create or replace function public.submit_proposal(
  p_job_id uuid, p_bid_amount numeric, p_estimated_days integer,
  p_cover_letter text, p_milestones jsonb default '[]'::jsonb
)
returns public.proposals
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.platform_settings := public.settings();
  v_uid uuid := auth.uid();
  v_job public.jobs;
  v_existing public.proposals;
  v_result public.proposals;
  v_limit integer;
  v_name text;
begin
  if v_uid is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not exists (select 1 from public.profiles where id = v_uid and role = 'freelancer') then
    raise exception 'ONLY_FREELANCERS_CAN_APPLY';
  end if;

  select * into v_job from public.jobs where id = p_job_id;
  if not found or v_job.status <> 'open' then raise exception 'JOB_NOT_OPEN'; end if;
  if v_job.client_id = v_uid then raise exception 'CANNOT_APPLY_TO_OWN_JOB'; end if;
  if char_length(trim(coalesce(p_cover_letter, ''))) < s.min_cover_letter_chars then
    raise exception 'COVER_LETTER_TOO_SHORT';
  end if;

  select * into v_existing from public.proposals
  where job_id = p_job_id and freelancer_id = v_uid for update;

  if found then
    if v_existing.status not in ('pending', 'counter_offered') then
      raise exception 'PROPOSAL_ALREADY_DECIDED';
    end if;
    update public.proposals set
      bid_amount = p_bid_amount, estimated_days = p_estimated_days,
      cover_letter = coalesce(p_cover_letter, ''), proposed_milestones = coalesce(p_milestones, '[]'::jsonb),
      status = 'pending', counter_price = null, counter_estimated_days = null,
      counter_message = null, counter_by_user_id = null, counter_created_at = null
    where id = v_existing.id returning * into v_result;
    return v_result;
  end if;

  -- Envio em massa: teto por 24 h vale para todos os planos.
  if (select count(*) from public.proposals
      where freelancer_id = v_uid and created_at > now() - interval '24 hours') >= s.daily_proposals then
    raise exception 'DAILY_PROPOSAL_LIMIT';
  end if;

  v_limit := case when public.is_pro(v_uid) then s.pro_monthly_proposals else s.free_monthly_proposals end;
  if public.counted_proposals(v_uid, date_trunc('month', now())) >= v_limit then
    raise exception 'PROPOSAL_QUOTA_EXCEEDED';
  end if;

  insert into public.proposals (job_id, freelancer_id, bid_amount, estimated_days, cover_letter, proposed_milestones)
  values (p_job_id, v_uid, p_bid_amount, p_estimated_days, coalesce(p_cover_letter, ''), coalesce(p_milestones, '[]'::jsonb))
  returning * into v_result;

  select full_name into v_name from public.profiles where id = v_uid;
  perform public.notify(
    v_job.client_id, 'proposal_received', 'Nova proposta recebida',
    coalesce(v_name, 'Um freelancer') || ' enviou uma proposta para "' || v_job.title || '".',
    jsonb_build_object('job_id', v_job.id, 'proposal_id', v_result.id,
                       'route', '/jobs/' || v_job.id || '/proposals')
  );
  return v_result;
end;
$$;

-- ---------------------------------------------------------------- Pro: modelos de proposta
create table public.proposal_templates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 60),
  cover_letter text not null check (char_length(cover_letter) <= 3000),
  estimated_days integer check (estimated_days is null or estimated_days > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index proposal_templates_user_idx on public.proposal_templates (user_id);
alter table public.proposal_templates enable row level security;
create policy proposal_templates_read_own on public.proposal_templates
  for select to authenticated using (user_id = (select auth.uid()));
-- Criar e editar é do Pro; quem deixou de ser Pro ainda lê e apaga os seus.
create policy proposal_templates_insert_pro on public.proposal_templates
  for insert to authenticated
  with check (user_id = (select auth.uid()) and public.is_pro((select auth.uid())));
create policy proposal_templates_update_pro on public.proposal_templates
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()) and public.is_pro((select auth.uid())));
create policy proposal_templates_delete_own on public.proposal_templates
  for delete to authenticated using (user_id = (select auth.uid()));
revoke all on public.proposal_templates from anon;

create function public.proposal_templates_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select count(*) from public.proposal_templates where user_id = new.user_id)
      >= (select max_proposal_templates from public.platform_settings limit 1) then
    raise exception 'TEMPLATE_LIMIT_REACHED';
  end if;
  return new;
end;
$$;
revoke all on function public.proposal_templates_limit() from public, anon, authenticated;
create trigger proposal_templates_limit_trg before insert on public.proposal_templates
  for each row execute function public.proposal_templates_limit();

-- ---------------------------------------------------------------- Pro: clientes e projetos
-- Anotações privadas do freelancer sobre cada cliente.
create table public.client_notes (
  freelancer_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  client_id uuid not null references public.profiles (id) on delete cascade,
  note text not null default '' check (char_length(note) <= 2000),
  tags text[] not null default '{}' check (cardinality(tags) <= 10),
  updated_at timestamptz not null default now(),
  primary key (freelancer_id, client_id)
);
alter table public.client_notes enable row level security;
create policy client_notes_read_own on public.client_notes
  for select to authenticated using (freelancer_id = (select auth.uid()));
create policy client_notes_write_pro on public.client_notes
  for insert to authenticated
  with check (freelancer_id = (select auth.uid()) and public.is_pro((select auth.uid())));
create policy client_notes_update_pro on public.client_notes
  for update to authenticated
  using (freelancer_id = (select auth.uid()))
  with check (freelancer_id = (select auth.uid()) and public.is_pro((select auth.uid())));
create policy client_notes_delete_own on public.client_notes
  for delete to authenticated using (freelancer_id = (select auth.uid()));
revoke all on public.client_notes from anon;

-- Clientes com quem o freelancer já negociou, com projetos e anotações.
create function public.freelancer_clients()
returns table (
  client_id uuid, client_name text, company_name text, avatar_url text,
  proposals_count bigint, accepted_count bigint, active_contracts bigint,
  completed_contracts bigint, total_accepted numeric, last_activity timestamptz,
  projects jsonb, note text, tags text[]
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if not public.is_pro(v_uid) then raise exception 'PRO_REQUIRED'; end if;
  return query
  select j.client_id, cp.full_name, cp.company_name, cp.avatar_url,
    count(p.id),
    count(p.id) filter (where p.status = 'accepted'),
    count(distinct c.id) filter (where c.status = 'active'),
    count(distinct c.id) filter (where c.status = 'completed'),
    coalesce(sum(p.bid_amount) filter (where p.status = 'accepted'), 0),
    max(greatest(p.updated_at, coalesce(c.completed_at, c.started_at, c.created_at, p.updated_at))),
    jsonb_agg(jsonb_build_object(
      'job_id', j.id, 'title', j.title, 'proposal_status', p.status,
      'contract_status', c.status, 'bid', p.bid_amount, 'created_at', p.created_at
    ) order by p.created_at desc),
    n.note, coalesce(n.tags, '{}')
  from public.proposals p
  join public.jobs j on j.id = p.job_id
  join public.profiles cp on cp.id = j.client_id
  left join public.contracts c on c.job_id = j.id and c.freelancer_id = v_uid
  left join public.client_notes n on n.freelancer_id = v_uid and n.client_id = j.client_id
  where p.freelancer_id = v_uid
  group by j.client_id, cp.full_name, cp.company_name, cp.avatar_url, n.note, n.tags
  order by 10 desc;
end;
$$;

-- ---------------------------------------------------------------- Pro: estatísticas
create function public.proposal_stats(p_days integer default 90)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_since timestamptz := now() - make_interval(days => greatest(least(p_days, 365), 7));
begin
  if not public.is_pro(v_uid) then raise exception 'PRO_REQUIRED'; end if;
  return (
    with mine as (
      select p.*, j.category, j.budget_min, j.budget_max
      from public.proposals p join public.jobs j on j.id = p.job_id
      where p.freelancer_id = v_uid and p.created_at >= v_since
    )
    select jsonb_build_object(
      'days', greatest(least(p_days, 365), 7),
      'sent', (select count(*) from mine),
      'accepted', (select count(*) from mine where status = 'accepted'),
      'rejected', (select count(*) from mine where status = 'rejected'),
      'pending', (select count(*) from mine where status in ('pending', 'counter_offered')),
      'negotiated', (select count(*) from mine where counter_created_at is not null),
      'avg_bid', (select round(avg(bid_amount), 2) from mine),
      -- Valor proposto em relação ao teto do orçamento do cliente (1 = igual ao teto).
      'avg_bid_vs_budget', (select round(avg(bid_amount / nullif(budget_max, 0)), 2) from mine where budget_max > 0),
      -- Horas até o cliente decidir (aceitar ou recusar).
      'avg_decision_hours', (select round(avg(extract(epoch from (updated_at - created_at)) / 3600)::numeric, 1)
                             from mine where status in ('accepted', 'rejected')),
      'by_category', coalesce((
        select jsonb_agg(row_to_json(c) order by c.sent desc) from (
          select category, count(*) as sent, count(*) filter (where status = 'accepted') as accepted
          from mine group by category
        ) c), '[]'::jsonb),
      'by_month', coalesce((
        select jsonb_agg(row_to_json(m) order by m.month) from (
          select to_char(date_trunc('month', created_at), 'YYYY-MM') as month,
                 count(*) as sent, count(*) filter (where status = 'accepted') as accepted
          from mine group by 1
        ) m), '[]'::jsonb)
    )
  );
end;
$$;

revoke all on function public.freelancer_clients() from public, anon;
revoke all on function public.proposal_stats(integer) from public, anon;
grant execute on function public.freelancer_clients() to authenticated;
grant execute on function public.proposal_stats(integer) to authenticated;
revoke execute on function public.settings() from anon;
