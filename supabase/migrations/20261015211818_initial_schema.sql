-- ============================================================================
-- FreelanceFlow — schema inicial
--
-- Modelo de negócio: marketplace SEM custódia de pagamentos. O pagamento do
-- projeto é combinado entre as partes; a plataforma monetiza com assinatura
-- Pro (freelancer) e destaque pago de vagas (cliente), cobrados via Asaas.
--
-- Princípios:
--   * Toda mudança de estado sensível passa por funções SECURITY DEFINER (RPC).
--   * Clientes (role `authenticated`) só têm GRANT de escrita nas colunas que
--     podem editar diretamente. Plano, rating, status e destaque são do servidor.
--   * RLS habilitado em todas as tabelas.
-- ============================================================================

create extension if not exists pgcrypto;

-- ----------------------------------------------------------------------------
-- Constantes de negócio
-- ----------------------------------------------------------------------------
create or replace function public.free_monthly_proposal_limit()
returns int language sql immutable set search_path = public as $$ select 5 $$;

-- ----------------------------------------------------------------------------
-- Utilitários
-- ----------------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger language plpgsql set search_path = public as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ----------------------------------------------------------------------------
-- profiles
-- ----------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null check (char_length(full_name) between 1 and 120),
  role text not null default 'freelancer'
    check (role in ('client', 'freelancer', 'admin')),
  avatar_url text,
  company_name text check (company_name is null or char_length(company_name) <= 120),
  bio text check (bio is null or char_length(bio) <= 2000),
  hourly_rate numeric(10, 2) not null default 0 check (hourly_rate >= 0),
  skills text[] not null default '{}',
  availability_status text not null default 'available'
    check (availability_status in ('available', 'busy', 'unavailable')),
  is_verified boolean not null default false,
  rating numeric(3, 2) not null default 0 check (rating between 0 and 5),
  reviews_count int not null default 0,
  completed_jobs_count int not null default 0,
  plan text not null default 'free' check (plan in ('free', 'pro')),
  plan_expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index profiles_role_idx on public.profiles (role);
create index profiles_skills_idx on public.profiles using gin (skills);

create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

alter table public.profiles enable row level security;

create policy profiles_select on public.profiles
  for select to authenticated using (true);
create policy profiles_update_own on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Apenas colunas cadastrais são editáveis pelo próprio usuário.
revoke insert, update, delete on public.profiles from authenticated, anon;
grant update (
  full_name, avatar_url, company_name, bio, hourly_rate, skills,
  availability_status
) on public.profiles to authenticated;

-- Cria o perfil automaticamente no cadastro. O papel inicial vem do metadado
-- do signUp, restrito a client/freelancer (nunca admin).
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_role text := coalesce(new.raw_user_meta_data ->> 'role', 'freelancer');
  v_name text := nullif(trim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), '');
begin
  if v_role not in ('client', 'freelancer') then
    v_role := 'freelancer';
  end if;
  insert into public.profiles (id, full_name, role)
  values (new.id, coalesce(v_name, split_part(new.email, '@', 1), 'Usuário'), v_role);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Troca de papel (cliente <-> freelancer); admin nunca é atribuível aqui.
create or replace function public.switch_role(p_role text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if p_role not in ('client', 'freelancer') then
    raise exception 'INVALID_ROLE';
  end if;
  update public.profiles set role = p_role
  where id = auth.uid() and role <> 'admin';
end;
$$;

-- Plano efetivo: considera expiração.
create or replace function public.is_pro(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(
    (select plan = 'pro' and (plan_expires_at is null or plan_expires_at > now())
       from public.profiles where id = p_user),
    false);
$$;

-- ----------------------------------------------------------------------------
-- portfolio_items
-- ----------------------------------------------------------------------------
create table public.portfolio_items (
  id uuid primary key default gen_random_uuid(),
  freelancer_id uuid not null references public.profiles (id) on delete cascade,
  title text not null check (char_length(title) between 1 and 120),
  description text not null default '',
  image_url text not null,
  project_url text,
  tags text[] not null default '{}',
  created_at timestamptz not null default now()
);
create index portfolio_items_freelancer_idx on public.portfolio_items (freelancer_id);

alter table public.portfolio_items enable row level security;
create policy portfolio_select on public.portfolio_items
  for select to authenticated using (true);
create policy portfolio_insert_own on public.portfolio_items
  for insert to authenticated with check (freelancer_id = auth.uid());
create policy portfolio_delete_own on public.portfolio_items
  for delete to authenticated using (freelancer_id = auth.uid());

-- ----------------------------------------------------------------------------
-- jobs
-- ----------------------------------------------------------------------------
create table public.jobs (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.profiles (id) on delete cascade,
  title text not null check (char_length(title) between 3 and 140),
  category text not null,
  description text not null check (char_length(description) >= 10),
  contract_type text not null default 'fixed' check (contract_type in ('fixed', 'hourly')),
  budget_min numeric(12, 2) not null check (budget_min >= 0),
  budget_max numeric(12, 2) not null,
  deadline_days int not null default 30 check (deadline_days > 0),
  experience_level text not null default 'all'
    check (experience_level in ('all', 'junior', 'pleno', 'senior')),
  status text not null default 'open'
    check (status in ('open', 'in_progress', 'completed', 'cancelled')),
  is_urgent boolean not null default false,
  featured_until timestamptz,
  skills_required text[] not null default '{}',
  attachments jsonb not null default '[]'::jsonb,
  image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint jobs_budget_range check (budget_max >= budget_min)
);

create index jobs_status_created_idx on public.jobs (status, created_at desc);
create index jobs_client_idx on public.jobs (client_id);
create index jobs_featured_idx on public.jobs (featured_until) where featured_until is not null;
create index jobs_category_idx on public.jobs (lower(category));

create trigger jobs_touch before update on public.jobs
  for each row execute function public.touch_updated_at();

alter table public.jobs enable row level security;
create policy jobs_select on public.jobs
  for select to authenticated using (true);
create policy jobs_insert_own on public.jobs
  for insert to authenticated with check (client_id = auth.uid());
create policy jobs_update_own on public.jobs
  for update to authenticated
  using (client_id = auth.uid() and status = 'open')
  with check (client_id = auth.uid());

revoke insert, update, delete on public.jobs from authenticated, anon;
grant insert (
  client_id, title, category, description, contract_type, budget_min, budget_max,
  deadline_days, experience_level, is_urgent, skills_required,
  attachments, image_url
) on public.jobs to authenticated;
grant update (
  title, category, description, contract_type, budget_min, budget_max,
  deadline_days, experience_level, is_urgent, skills_required,
  attachments, image_url
) on public.jobs to authenticated;

-- Só clientes publicam vagas.
create or replace function public.jobs_require_client()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.profiles where id = new.client_id and role = 'client') then
    raise exception 'ONLY_CLIENTS_CAN_POST_JOBS';
  end if;
  return new;
end;
$$;
create trigger jobs_require_client_trg before insert on public.jobs
  for each row execute function public.jobs_require_client();

create or replace function public.cancel_job(p_job_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.jobs set status = 'cancelled'
  where id = p_job_id and client_id = auth.uid() and status = 'open';
  if not found then raise exception 'JOB_NOT_CANCELLABLE'; end if;
  update public.proposals set status = 'rejected'
  where job_id = p_job_id and status in ('pending', 'counter_offered');
end;
$$;

-- ----------------------------------------------------------------------------
-- proposals
-- ----------------------------------------------------------------------------
create table public.proposals (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs (id) on delete cascade,
  freelancer_id uuid not null references public.profiles (id) on delete cascade,
  bid_amount numeric(12, 2) not null check (bid_amount > 0),
  estimated_days int not null check (estimated_days > 0),
  cover_letter text not null default '',
  proposed_milestones jsonb not null default '[]'::jsonb,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'rejected', 'counter_offered')),
  counter_price numeric(12, 2) check (counter_price is null or counter_price > 0),
  counter_estimated_days int check (counter_estimated_days is null or counter_estimated_days > 0),
  counter_message text,
  counter_by_user_id uuid references public.profiles (id) on delete set null,
  counter_created_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (job_id, freelancer_id)
);
create index proposals_job_idx on public.proposals (job_id, created_at desc);
create index proposals_freelancer_idx on public.proposals (freelancer_id, created_at desc);

create trigger proposals_touch before update on public.proposals
  for each row execute function public.touch_updated_at();

alter table public.proposals enable row level security;
-- O freelancer vê as próprias propostas; o cliente vê as propostas das suas vagas.
create policy proposals_select on public.proposals
  for select to authenticated using (
    freelancer_id = auth.uid()
    or exists (select 1 from public.jobs j where j.id = job_id and j.client_id = auth.uid())
  );
-- Escrita somente via RPC (garante cota do plano e máquina de estados).
revoke insert, update, delete on public.proposals from authenticated, anon;

-- ----------------------------------------------------------------------------
-- contracts / milestones / milestone_revisions
-- ----------------------------------------------------------------------------
create table public.contracts (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs (id) on delete restrict,
  proposal_id uuid not null unique references public.proposals (id) on delete restrict,
  client_id uuid not null references public.profiles (id) on delete restrict,
  freelancer_id uuid not null references public.profiles (id) on delete restrict,
  -- Valor acordado entre as partes (informativo; a plataforma não custodia).
  total_amount numeric(12, 2) not null check (total_amount > 0),
  estimated_days int not null check (estimated_days > 0),
  status text not null default 'active' check (status in ('active', 'completed', 'cancelled')),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  created_at timestamptz not null default now()
);
create index contracts_client_idx on public.contracts (client_id, status);
create index contracts_freelancer_idx on public.contracts (freelancer_id, status);

alter table public.contracts enable row level security;
create policy contracts_select on public.contracts
  for select to authenticated using (client_id = auth.uid() or freelancer_id = auth.uid());
revoke insert, update, delete on public.contracts from authenticated, anon;

create table public.milestones (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.contracts (id) on delete cascade,
  title text not null,
  description text not null default '',
  amount numeric(12, 2) not null default 0 check (amount >= 0),
  sort_order int not null default 0,
  status text not null default 'pending'
    check (status in ('pending', 'submitted', 'in_revision', 'approved')),
  due_date date,
  deliverable_notes text,
  deliverable_attachments jsonb not null default '[]'::jsonb,
  submitted_at timestamptz,
  approved_at timestamptz,
  revision_count int not null default 0,
  created_at timestamptz not null default now()
);
create index milestones_contract_idx on public.milestones (contract_id, sort_order);

alter table public.milestones enable row level security;
create policy milestones_select on public.milestones
  for select to authenticated using (
    exists (select 1 from public.contracts c
            where c.id = contract_id
              and (c.client_id = auth.uid() or c.freelancer_id = auth.uid()))
  );
revoke insert, update, delete on public.milestones from authenticated, anon;

create table public.milestone_revisions (
  id uuid primary key default gen_random_uuid(),
  milestone_id uuid not null references public.milestones (id) on delete cascade,
  contract_id uuid not null references public.contracts (id) on delete cascade,
  requested_by uuid not null references public.profiles (id) on delete cascade,
  comment text not null,
  attachments jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);
create index milestone_revisions_milestone_idx on public.milestone_revisions (milestone_id, created_at desc);

alter table public.milestone_revisions enable row level security;
create policy milestone_revisions_select on public.milestone_revisions
  for select to authenticated using (
    exists (select 1 from public.contracts c
            where c.id = contract_id
              and (c.client_id = auth.uid() or c.freelancer_id = auth.uid()))
  );
revoke insert, update, delete on public.milestone_revisions from authenticated, anon;

-- ----------------------------------------------------------------------------
-- conversations / messages
-- ----------------------------------------------------------------------------
create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  job_id uuid references public.jobs (id) on delete set null,
  client_id uuid not null references public.profiles (id) on delete cascade,
  freelancer_id uuid not null references public.profiles (id) on delete cascade,
  contract_id uuid references public.contracts (id) on delete set null,
  last_message_at timestamptz not null default now(),
  last_message_preview text,
  created_at timestamptz not null default now(),
  check (client_id <> freelancer_id)
);
create unique index conversations_unique_idx on public.conversations (
  client_id, freelancer_id, coalesce(job_id, '00000000-0000-0000-0000-000000000000'::uuid)
);
create index conversations_client_idx on public.conversations (client_id, last_message_at desc);
create index conversations_freelancer_idx on public.conversations (freelancer_id, last_message_at desc);

alter table public.conversations enable row level security;
create policy conversations_select on public.conversations
  for select to authenticated using (client_id = auth.uid() or freelancer_id = auth.uid());
revoke insert, update, delete on public.conversations from authenticated, anon;

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  content text not null default '' check (char_length(content) <= 5000),
  message_type text not null default 'text'
    check (message_type in ('text', 'system_event', 'milestone_update', 'image', 'file', 'document')),
  attachment_url text,
  attachment_name text,
  attachment_size int,
  attachment_mime text,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create index messages_conversation_idx on public.messages (conversation_id, created_at);

alter table public.messages enable row level security;
create policy messages_select on public.messages
  for select to authenticated using (
    exists (select 1 from public.conversations c
            where c.id = conversation_id
              and (c.client_id = auth.uid() or c.freelancer_id = auth.uid()))
  );
-- Mensagens de usuário: apenas tipos não-sistema e como remetente próprio.
create policy messages_insert on public.messages
  for insert to authenticated with check (
    sender_id = auth.uid()
    and message_type in ('text', 'image', 'file', 'document')
    and exists (select 1 from public.conversations c
                where c.id = conversation_id
                  and (c.client_id = auth.uid() or c.freelancer_id = auth.uid()))
  );
revoke insert, update, delete on public.messages from authenticated, anon;
grant insert (
  conversation_id, sender_id, content, message_type,
  attachment_url, attachment_name, attachment_size, attachment_mime
) on public.messages to authenticated;

-- ----------------------------------------------------------------------------
-- notifications
-- ----------------------------------------------------------------------------
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  type text not null default 'system',
  title text not null,
  body text not null default '',
  data jsonb not null default '{}'::jsonb,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create index notifications_user_idx on public.notifications (user_id, created_at desc);

alter table public.notifications enable row level security;
create policy notifications_select_own on public.notifications
  for select to authenticated using (user_id = auth.uid());
create policy notifications_update_own on public.notifications
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy notifications_delete_own on public.notifications
  for delete to authenticated using (user_id = auth.uid());
revoke insert, update, delete on public.notifications from authenticated, anon;
grant update (is_read) on public.notifications to authenticated;
grant delete on public.notifications to authenticated;

create or replace function public.notify(
  p_user uuid, p_type text, p_title text, p_body text, p_data jsonb default '{}'::jsonb
) returns void language plpgsql security definer set search_path = public as $$
begin
  if p_user is null then return; end if;
  insert into public.notifications (user_id, type, title, body, data)
  values (p_user, p_type, p_title, coalesce(p_body, ''), coalesce(p_data, '{}'::jsonb));
end;
$$;
revoke execute on function public.notify(uuid, text, text, text, jsonb) from public, anon, authenticated;

create or replace function public.mark_all_notifications_as_read()
returns int language plpgsql security definer set search_path = public as $$
declare v_count int;
begin
  update public.notifications set is_read = true
  where user_id = auth.uid() and is_read = false;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ----------------------------------------------------------------------------
-- reviews
-- ----------------------------------------------------------------------------
create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.contracts (id) on delete cascade,
  reviewer_id uuid not null references public.profiles (id) on delete cascade,
  target_id uuid not null references public.profiles (id) on delete cascade,
  rating int not null check (rating between 1 and 5),
  comment text check (comment is null or char_length(comment) <= 2000),
  created_at timestamptz not null default now(),
  unique (contract_id, reviewer_id),
  check (reviewer_id <> target_id)
);
create index reviews_target_idx on public.reviews (target_id, created_at desc);

alter table public.reviews enable row level security;
create policy reviews_select on public.reviews
  for select to authenticated using (true);
-- Só as partes do contrato avaliam uma à outra.
create policy reviews_insert on public.reviews
  for insert to authenticated with check (
    reviewer_id = auth.uid()
    and exists (
      select 1 from public.contracts c
      where c.id = contract_id
        and ((c.client_id = reviewer_id and c.freelancer_id = target_id)
          or (c.freelancer_id = reviewer_id and c.client_id = target_id))
    )
  );
revoke insert, update, delete on public.reviews from authenticated, anon;
grant insert (contract_id, reviewer_id, target_id, rating, comment) on public.reviews to authenticated;

create or replace function public.refresh_profile_rating()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.profiles p set
    rating = coalesce((select round(avg(rating)::numeric, 2) from public.reviews where target_id = new.target_id), 0),
    reviews_count = (select count(*) from public.reviews where target_id = new.target_id)
  where p.id = new.target_id;
  return null;
end;
$$;
create trigger reviews_refresh_rating after insert on public.reviews
  for each row execute function public.refresh_profile_rating();

-- ----------------------------------------------------------------------------
-- Billing (cobrança via Asaas — escrita exclusiva do service_role)
-- ----------------------------------------------------------------------------
create table public.billing_customers (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  asaas_customer_id text not null unique,
  created_at timestamptz not null default now()
);
alter table public.billing_customers enable row level security;
revoke all on public.billing_customers from authenticated, anon;

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  asaas_subscription_id text not null unique,
  plan text not null default 'pro' check (plan in ('pro')),
  billing_type text not null check (billing_type in ('PIX', 'CREDIT_CARD', 'BOLETO')),
  status text not null default 'pending'
    check (status in ('pending', 'active', 'overdue', 'cancelled')),
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index subscriptions_user_idx on public.subscriptions (user_id, created_at desc);
create trigger subscriptions_touch before update on public.subscriptions
  for each row execute function public.touch_updated_at();

alter table public.subscriptions enable row level security;
create policy subscriptions_select_own on public.subscriptions
  for select to authenticated using (user_id = auth.uid());
revoke insert, update, delete on public.subscriptions from authenticated, anon;

create table public.job_featurings (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  asaas_payment_id text not null unique,
  days int not null check (days > 0),
  amount numeric(10, 2) not null check (amount > 0),
  status text not null default 'pending' check (status in ('pending', 'paid', 'cancelled')),
  paid_at timestamptz,
  created_at timestamptz not null default now()
);
create index job_featurings_job_idx on public.job_featurings (job_id);

alter table public.job_featurings enable row level security;
create policy job_featurings_select_own on public.job_featurings
  for select to authenticated using (user_id = auth.uid());
revoke insert, update, delete on public.job_featurings from authenticated, anon;

-- Idempotência do webhook do Asaas.
create table public.billing_events (
  id text primary key,
  event text not null,
  payload jsonb not null,
  processed_at timestamptz not null default now()
);
alter table public.billing_events enable row level security;
revoke all on public.billing_events from authenticated, anon;

-- Cota de propostas do mês (plano grátis).
create or replace function public.proposal_quota()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_pro boolean := public.is_pro(auth.uid());
  v_used int;
begin
  select count(*) into v_used from public.proposals
  where freelancer_id = auth.uid() and created_at >= date_trunc('month', now());
  return jsonb_build_object(
    'is_pro', v_pro,
    'monthly_limit', case when v_pro then null else public.free_monthly_proposal_limit() end,
    'used', v_used,
    'remaining', case when v_pro then null
                      else greatest(public.free_monthly_proposal_limit() - v_used, 0) end
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- Conversas e mensagens
-- ----------------------------------------------------------------------------
create or replace function public.get_or_create_conversation(
  p_client_id uuid, p_freelancer_id uuid, p_job_id uuid default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if auth.uid() not in (p_client_id, p_freelancer_id) then
    raise exception 'FORBIDDEN';
  end if;
  select id into v_id from public.conversations
  where client_id = p_client_id and freelancer_id = p_freelancer_id
    and job_id is not distinct from p_job_id;
  if v_id is null then
    insert into public.conversations (client_id, freelancer_id, job_id)
    values (p_client_id, p_freelancer_id, p_job_id)
    on conflict do nothing
    returning id into v_id;
    if v_id is null then
      select id into v_id from public.conversations
      where client_id = p_client_id and freelancer_id = p_freelancer_id
        and job_id is not distinct from p_job_id;
    end if;
  end if;
  return v_id;
end;
$$;

create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.messages m set is_read = true
  where m.conversation_id = p_conversation_id
    and m.sender_id <> auth.uid()
    and m.is_read = false
    and exists (select 1 from public.conversations c
                where c.id = p_conversation_id
                  and (c.client_id = auth.uid() or c.freelancer_id = auth.uid()));
end;
$$;

-- Mensagem de sistema na conversa do contrato.
create or replace function public._system_message(
  p_conversation_id uuid, p_sender uuid, p_content text
) returns void language sql security definer set search_path = public as $$
  insert into public.messages (conversation_id, sender_id, content, message_type)
  values (p_conversation_id, p_sender, p_content, 'system_event');
$$;
revoke execute on function public._system_message(uuid, uuid, text) from public, anon, authenticated;

create or replace function public.on_message_inserted()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_conv public.conversations;
  v_recipient uuid;
  v_sender_name text;
begin
  update public.conversations set
    last_message_at = new.created_at,
    last_message_preview = left(new.content, 140)
  where id = new.conversation_id returning * into v_conv;

  if new.message_type = 'system_event' then return null; end if;

  v_recipient := case when new.sender_id = v_conv.client_id
                      then v_conv.freelancer_id else v_conv.client_id end;

  -- Evita spam: uma notificação não lida por conversa.
  if not exists (
    select 1 from public.notifications
    where user_id = v_recipient and type = 'new_message' and is_read = false
      and data ->> 'conversation_id' = new.conversation_id::text
  ) then
    select full_name into v_sender_name from public.profiles where id = new.sender_id;
    perform public.notify(
      v_recipient, 'new_message', 'Nova mensagem de ' || coalesce(v_sender_name, 'um usuário'),
      left(new.content, 140),
      jsonb_build_object('conversation_id', new.conversation_id,
                         'route', '/chat/' || new.conversation_id)
    );
  end if;
  return null;
end;
$$;
create trigger messages_after_insert after insert on public.messages
  for each row execute function public.on_message_inserted();

-- ----------------------------------------------------------------------------
-- Propostas (máquina de estados no servidor)
-- ----------------------------------------------------------------------------
create or replace function public.submit_proposal(
  p_job_id uuid,
  p_bid_amount numeric,
  p_estimated_days int,
  p_cover_letter text,
  p_milestones jsonb default '[]'::jsonb
) returns public.proposals language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_job public.jobs;
  v_existing public.proposals;
  v_result public.proposals;
  v_used int;
  v_name text;
begin
  if v_uid is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not exists (select 1 from public.profiles where id = v_uid and role = 'freelancer') then
    raise exception 'ONLY_FREELANCERS_CAN_APPLY';
  end if;

  select * into v_job from public.jobs where id = p_job_id;
  if not found or v_job.status <> 'open' then raise exception 'JOB_NOT_OPEN'; end if;
  if v_job.client_id = v_uid then raise exception 'CANNOT_APPLY_TO_OWN_JOB'; end if;

  select * into v_existing from public.proposals
  where job_id = p_job_id and freelancer_id = v_uid for update;

  if found then
    if v_existing.status not in ('pending', 'counter_offered') then
      raise exception 'PROPOSAL_ALREADY_DECIDED';
    end if;
    -- Edição de proposta existente não consome cota.
    update public.proposals set
      bid_amount = p_bid_amount, estimated_days = p_estimated_days,
      cover_letter = coalesce(p_cover_letter, ''), proposed_milestones = coalesce(p_milestones, '[]'::jsonb),
      status = 'pending', counter_price = null, counter_estimated_days = null,
      counter_message = null, counter_by_user_id = null, counter_created_at = null
    where id = v_existing.id returning * into v_result;
    return v_result;
  end if;

  if not public.is_pro(v_uid) then
    select count(*) into v_used from public.proposals
    where freelancer_id = v_uid and created_at >= date_trunc('month', now());
    if v_used >= public.free_monthly_proposal_limit() then
      raise exception 'PROPOSAL_QUOTA_EXCEEDED';
    end if;
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

-- Criação atômica do contrato (interno). Valor e prazo vêm da proposta.
create or replace function public._create_contract(p_proposal_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_prop public.proposals;
  v_job public.jobs;
  v_contract_id uuid;
  v_conv_id uuid;
  v_sum numeric;
  v_ms jsonb;
begin
  select * into v_prop from public.proposals where id = p_proposal_id for update;
  select * into v_job from public.jobs where id = v_prop.job_id for update;
  if v_job.status <> 'open' then raise exception 'JOB_NOT_OPEN'; end if;

  insert into public.contracts (job_id, proposal_id, client_id, freelancer_id, total_amount, estimated_days)
  values (v_job.id, v_prop.id, v_job.client_id, v_prop.freelancer_id, v_prop.bid_amount, v_prop.estimated_days)
  returning id into v_contract_id;

  -- Marcos propostos só valem se somarem o valor acordado; senão, marco único.
  select coalesce(sum((m ->> 'amount')::numeric), 0) into v_sum
  from jsonb_array_elements(v_prop.proposed_milestones) m;
  if jsonb_array_length(v_prop.proposed_milestones) > 0 and v_sum = v_prop.bid_amount then
    v_ms := v_prop.proposed_milestones;
  else
    v_ms := jsonb_build_array(jsonb_build_object(
      'title', 'Entrega do projeto', 'amount', v_prop.bid_amount, 'days', v_prop.estimated_days));
  end if;

  insert into public.milestones (contract_id, title, amount, sort_order, due_date)
  select v_contract_id,
         coalesce(nullif(m.elem ->> 'title', ''), 'Marco ' || m.ord),
         coalesce((m.elem ->> 'amount')::numeric, 0),
         m.ord,
         current_date + coalesce((m.elem ->> 'days')::int, v_prop.estimated_days)
  from jsonb_array_elements(v_ms) with ordinality as m(elem, ord);

  update public.proposals set status = 'accepted' where id = v_prop.id;
  update public.proposals set status = 'rejected'
  where job_id = v_job.id and id <> v_prop.id and status in ('pending', 'counter_offered');
  update public.jobs set status = 'in_progress' where id = v_job.id;

  v_conv_id := public.get_or_create_conversation_internal(v_job.client_id, v_prop.freelancer_id, v_job.id);
  update public.conversations set contract_id = v_contract_id where id = v_conv_id;

  perform public._system_message(v_conv_id, v_job.client_id,
    '🤝 Contrato iniciado para "' || v_job.title || '". Combinem prazos e forma de pagamento aqui no chat.');
  perform public.notify(
    v_prop.freelancer_id, 'proposal_accepted', 'Proposta aceita! 🎉',
    'Sua proposta para "' || v_job.title || '" foi aceita.',
    jsonb_build_object('job_id', v_job.id, 'contract_id', v_contract_id,
                       'conversation_id', v_conv_id, 'route', '/chat/' || v_conv_id)
  );
  return jsonb_build_object('contract_id', v_contract_id, 'conversation_id', v_conv_id);
end;
$$;
revoke execute on function public._create_contract(uuid) from public, anon, authenticated;

-- Versão interna (sem checagem de auth.uid) usada por _create_contract.
create or replace function public.get_or_create_conversation_internal(
  p_client_id uuid, p_freelancer_id uuid, p_job_id uuid
) returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  select id into v_id from public.conversations
  where client_id = p_client_id and freelancer_id = p_freelancer_id
    and job_id is not distinct from p_job_id;
  if v_id is null then
    insert into public.conversations (client_id, freelancer_id, job_id)
    values (p_client_id, p_freelancer_id, p_job_id) returning id into v_id;
  end if;
  return v_id;
end;
$$;
revoke execute on function public.get_or_create_conversation_internal(uuid, uuid, uuid) from public, anon, authenticated;

create or replace function public.accept_proposal(p_proposal_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_prop public.proposals;
begin
  select p.* into v_prop from public.proposals p
  join public.jobs j on j.id = p.job_id
  where p.id = p_proposal_id and j.client_id = auth.uid();
  if not found then raise exception 'PROPOSAL_NOT_FOUND'; end if;
  if v_prop.status <> 'pending' then raise exception 'PROPOSAL_NOT_PENDING'; end if;
  return public._create_contract(p_proposal_id);
end;
$$;

create or replace function public.reject_proposal(p_proposal_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_prop public.proposals; v_job public.jobs;
begin
  select p.* into v_prop from public.proposals p
  join public.jobs j on j.id = p.job_id
  where p.id = p_proposal_id and j.client_id = auth.uid();
  if not found then raise exception 'PROPOSAL_NOT_FOUND'; end if;
  if v_prop.status not in ('pending', 'counter_offered') then
    raise exception 'PROPOSAL_ALREADY_DECIDED';
  end if;
  update public.proposals set status = 'rejected' where id = p_proposal_id;
  select * into v_job from public.jobs where id = v_prop.job_id;
  perform public.notify(v_prop.freelancer_id, 'system', 'Proposta não selecionada',
    'Sua proposta para "' || v_job.title || '" não foi selecionada.',
    jsonb_build_object('job_id', v_job.id, 'route', '/jobs/' || v_job.id));
end;
$$;

create or replace function public.make_counter_offer(
  p_proposal_id uuid, p_price numeric, p_days int, p_message text default null
) returns void language plpgsql security definer set search_path = public as $$
declare v_prop public.proposals; v_job public.jobs;
begin
  select p.* into v_prop from public.proposals p
  join public.jobs j on j.id = p.job_id
  where p.id = p_proposal_id and j.client_id = auth.uid();
  if not found then raise exception 'PROPOSAL_NOT_FOUND'; end if;
  if v_prop.status not in ('pending', 'counter_offered') then
    raise exception 'PROPOSAL_ALREADY_DECIDED';
  end if;
  if p_price is null or p_price <= 0 or p_days is null or p_days <= 0 then
    raise exception 'INVALID_COUNTER_OFFER';
  end if;
  update public.proposals set
    status = 'counter_offered', counter_price = p_price, counter_estimated_days = p_days,
    counter_message = nullif(trim(coalesce(p_message, '')), ''),
    counter_by_user_id = auth.uid(), counter_created_at = now()
  where id = p_proposal_id;
  select * into v_job from public.jobs where id = v_prop.job_id;
  perform public.notify(v_prop.freelancer_id, 'proposal_received', 'Você recebeu uma contraproposta',
    'O cliente enviou uma contraproposta para "' || v_job.title || '".',
    jsonb_build_object('job_id', v_job.id, 'proposal_id', p_proposal_id,
                       'route', '/jobs/' || v_job.id || '/apply'));
end;
$$;

create or replace function public.accept_counter_offer(p_proposal_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_prop public.proposals;
begin
  select * into v_prop from public.proposals
  where id = p_proposal_id and freelancer_id = auth.uid() for update;
  if not found then raise exception 'PROPOSAL_NOT_FOUND'; end if;
  if v_prop.status <> 'counter_offered' or v_prop.counter_price is null then
    raise exception 'NO_ACTIVE_COUNTER_OFFER';
  end if;
  update public.proposals set
    bid_amount = v_prop.counter_price,
    estimated_days = coalesce(v_prop.counter_estimated_days, v_prop.estimated_days)
  where id = p_proposal_id;
  return public._create_contract(p_proposal_id);
end;
$$;

create or replace function public.reject_counter_offer(p_proposal_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.proposals set
    status = 'pending', counter_price = null, counter_estimated_days = null,
    counter_message = null, counter_by_user_id = null, counter_created_at = null
  where id = p_proposal_id and freelancer_id = auth.uid() and status = 'counter_offered';
  if not found then raise exception 'NO_ACTIVE_COUNTER_OFFER'; end if;
end;
$$;

-- ----------------------------------------------------------------------------
-- Entregas por marco (sem movimentação financeira)
-- ----------------------------------------------------------------------------
create or replace function public._milestone_context(p_milestone_id uuid)
returns table (milestone_id uuid, contract_id uuid, client_id uuid, freelancer_id uuid,
               conversation_id uuid, title text, job_title text)
language sql stable security definer set search_path = public as $$
  select m.id, c.id, c.client_id, c.freelancer_id,
         (select cv.id from public.conversations cv where cv.contract_id = c.id limit 1),
         m.title, j.title
  from public.milestones m
  join public.contracts c on c.id = m.contract_id
  join public.jobs j on j.id = c.job_id
  where m.id = p_milestone_id;
$$;
revoke execute on function public._milestone_context(uuid) from public, anon, authenticated;

create or replace function public.submit_deliverable(
  p_milestone_id uuid, p_notes text, p_attachments jsonb default '[]'::jsonb
) returns void language plpgsql security definer set search_path = public as $$
declare ctx record; v_status text;
begin
  select * into ctx from public._milestone_context(p_milestone_id);
  if not found or ctx.freelancer_id <> auth.uid() then raise exception 'MILESTONE_NOT_FOUND'; end if;
  select status into v_status from public.milestones where id = p_milestone_id for update;
  if v_status not in ('pending', 'in_revision') then raise exception 'MILESTONE_NOT_DELIVERABLE'; end if;
  if not exists (select 1 from public.contracts where id = ctx.contract_id and status = 'active') then
    raise exception 'CONTRACT_NOT_ACTIVE';
  end if;
  update public.milestones set
    status = 'submitted', deliverable_notes = trim(coalesce(p_notes, '')),
    deliverable_attachments = coalesce(p_attachments, '[]'::jsonb), submitted_at = now()
  where id = p_milestone_id;
  if ctx.conversation_id is not null then
    perform public._system_message(ctx.conversation_id, auth.uid(),
      '📦 Entrega enviada para o marco "' || ctx.title || '":' || E'\n\n"' || trim(coalesce(p_notes, '')) || '"'
      || case when jsonb_array_length(coalesce(p_attachments, '[]'::jsonb)) > 0
              then E'\n(' || jsonb_array_length(p_attachments) || ' arquivo(s) anexado(s))' else '' end);
  end if;
  perform public.notify(ctx.client_id, 'milestone_submitted', 'Entrega recebida',
    'O marco "' || ctx.title || '" de "' || ctx.job_title || '" aguarda sua análise.',
    jsonb_build_object('contract_id', ctx.contract_id, 'milestone_id', p_milestone_id,
                       'conversation_id', ctx.conversation_id,
                       'route', '/chat/' || coalesce(ctx.conversation_id::text, '')));
end;
$$;

create or replace function public.request_revision(
  p_milestone_id uuid, p_comment text, p_attachments jsonb default '[]'::jsonb
) returns void language plpgsql security definer set search_path = public as $$
declare ctx record; v_status text;
begin
  if p_comment is null or length(trim(p_comment)) = 0 then raise exception 'COMMENT_REQUIRED'; end if;
  select * into ctx from public._milestone_context(p_milestone_id);
  if not found or ctx.client_id <> auth.uid() then raise exception 'MILESTONE_NOT_FOUND'; end if;
  select status into v_status from public.milestones where id = p_milestone_id for update;
  if v_status <> 'submitted' then raise exception 'MILESTONE_NOT_SUBMITTED'; end if;
  insert into public.milestone_revisions (milestone_id, contract_id, requested_by, comment, attachments)
  values (p_milestone_id, ctx.contract_id, auth.uid(), trim(p_comment), coalesce(p_attachments, '[]'::jsonb));
  update public.milestones set status = 'in_revision', revision_count = revision_count + 1
  where id = p_milestone_id;
  if ctx.conversation_id is not null then
    perform public._system_message(ctx.conversation_id, auth.uid(),
      '🔄 Revisão solicitada no marco "' || ctx.title || '":' || E'\n\n"' || trim(p_comment) || '"');
  end if;
  perform public.notify(ctx.freelancer_id, 'milestone_in_revision', 'Ajustes solicitados',
    'O cliente pediu ajustes no marco "' || ctx.title || '".',
    jsonb_build_object('contract_id', ctx.contract_id, 'milestone_id', p_milestone_id,
                       'conversation_id', ctx.conversation_id,
                       'route', '/chat/' || coalesce(ctx.conversation_id::text, '')));
end;
$$;

create or replace function public.approve_milestone(p_milestone_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare ctx record; v_status text; v_pending int; v_completed boolean := false;
begin
  select * into ctx from public._milestone_context(p_milestone_id);
  if not found or ctx.client_id <> auth.uid() then raise exception 'MILESTONE_NOT_FOUND'; end if;
  select status into v_status from public.milestones where id = p_milestone_id for update;
  if v_status <> 'submitted' then raise exception 'MILESTONE_NOT_SUBMITTED'; end if;
  update public.milestones set status = 'approved', approved_at = now() where id = p_milestone_id;

  if ctx.conversation_id is not null then
    perform public._system_message(ctx.conversation_id, auth.uid(),
      '🎉 Marco "' || ctx.title || '" aprovado pelo cliente!');
  end if;
  perform public.notify(ctx.freelancer_id, 'milestone_approved', 'Entrega aprovada 🎉',
    'O marco "' || ctx.title || '" foi aprovado.',
    jsonb_build_object('contract_id', ctx.contract_id, 'milestone_id', p_milestone_id,
                       'conversation_id', ctx.conversation_id,
                       'route', '/chat/' || coalesce(ctx.conversation_id::text, '')));

  select count(*) into v_pending from public.milestones
  where contract_id = ctx.contract_id and status <> 'approved';
  if v_pending = 0 then
    update public.contracts set status = 'completed', completed_at = now()
    where id = ctx.contract_id and status = 'active';
    update public.jobs set status = 'completed'
    where id = (select job_id from public.contracts where id = ctx.contract_id);
    update public.profiles set completed_jobs_count = completed_jobs_count + 1
    where id = ctx.freelancer_id;
    v_completed := true;
    if ctx.conversation_id is not null then
      perform public._system_message(ctx.conversation_id, auth.uid(),
        '✅ Projeto concluído! Deixe sua avaliação para a outra parte.');
    end if;
    perform public.notify(ctx.client_id, 'system', 'Projeto concluído',
      '"' || ctx.job_title || '" foi concluído. Avalie o freelancer!',
      jsonb_build_object('contract_id', ctx.contract_id, 'conversation_id', ctx.conversation_id,
                         'route', '/chat/' || coalesce(ctx.conversation_id::text, '')));
  end if;
  return jsonb_build_object('contract_completed', v_completed);
end;
$$;

-- ----------------------------------------------------------------------------
-- Permissões de execução das RPCs públicas
-- ----------------------------------------------------------------------------
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function
  public.switch_role(text),
  public.cancel_job(uuid),
  public.mark_all_notifications_as_read(),
  public.proposal_quota(),
  public.get_or_create_conversation(uuid, uuid, uuid),
  public.mark_conversation_read(uuid),
  public.submit_proposal(uuid, numeric, int, text, jsonb),
  public.accept_proposal(uuid),
  public.reject_proposal(uuid),
  public.make_counter_offer(uuid, numeric, int, text),
  public.accept_counter_offer(uuid),
  public.reject_counter_offer(uuid),
  public.submit_deliverable(uuid, text, jsonb),
  public.request_revision(uuid, text, jsonb),
  public.approve_milestone(uuid)
to authenticated;

-- ----------------------------------------------------------------------------
-- Storage
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit)
values
  ('avatars', 'avatars', true, 5242880),
  ('portfolio', 'portfolio', true, 10485760),
  ('job_attachments', 'job_attachments', true, 20971520),
  ('job_covers', 'job_covers', true, 10485760),
  ('chat_attachments', 'chat_attachments', true, 20971520)
on conflict (id) do nothing;

-- Convenção de caminho: <bucket>/<user_id>/<arquivo>. Só o dono escreve na própria pasta.
create policy "storage_read_public_buckets" on storage.objects
  for select using (bucket_id in ('avatars', 'portfolio', 'job_attachments', 'job_covers', 'chat_attachments'));
create policy "storage_insert_own_folder" on storage.objects
  for insert to authenticated with check (
    bucket_id in ('avatars', 'portfolio', 'job_attachments', 'job_covers', 'chat_attachments')
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "storage_delete_own_folder" on storage.objects
  for delete to authenticated using (
    bucket_id in ('avatars', 'portfolio', 'job_attachments', 'job_covers', 'chat_attachments')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ----------------------------------------------------------------------------
-- Realtime
-- ----------------------------------------------------------------------------
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.conversations;
