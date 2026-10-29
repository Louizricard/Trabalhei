-- Inbox durável; registros antigos continuam fechados, sem reaplicar dinheiro.
alter table public.billing_events
  alter column processed_at drop not null,
  add column received_at timestamptz not null default now(),
  add column processing_status text not null default 'legacy'
    check (processing_status in ('legacy', 'pending', 'failed', 'processed', 'ignored')),
  add column attempts integer not null default 0 check (attempts >= 0),
  add column last_error_code text;

create index billing_events_pending_payment_idx
  on public.billing_events ((payload #>> '{payment,id}'))
  where processing_status in ('pending', 'failed');
create index billing_events_pending_subscription_idx
  on public.billing_events ((coalesce(payload #>> '{payment,subscription}', payload #>> '{subscription,id}')))
  where processing_status in ('pending', 'failed');

-- Um pagamento pode gerar CONFIRMED e RECEIVED com ids de evento diferentes.
create table public.billing_payment_receipts (
  payment_id text primary key,
  product text not null check (product in ('pro_monthly', 'job_feature')),
  event_id text references public.billing_events (id) on delete set null,
  applied_at timestamptz not null default now(),
  expires_at timestamptz not null
);
create index billing_payment_receipts_event_idx on public.billing_payment_receipts (event_id);
alter table public.billing_payment_receipts enable row level security;
revoke all on public.billing_payment_receipts from public, anon, authenticated;
grant all on public.billing_payment_receipts to service_role;

-- Só efeitos já confirmados localmente entram no histórico de deduplicação.
insert into public.billing_payment_receipts (payment_id, product, applied_at, expires_at)
select f.asaas_payment_id, 'job_feature', coalesce(f.paid_at, f.created_at), j.featured_until
from public.job_featurings f join public.jobs j on j.id = f.job_id
where f.status = 'paid' and j.featured_until is not null
on conflict (payment_id) do nothing;

insert into public.billing_payment_receipts (payment_id, product, event_id, applied_at, expires_at)
select distinct on (e.payload #>> '{payment,id}')
  e.payload #>> '{payment,id}', 'pro_monthly', e.id, e.processed_at, s.current_period_end
from public.billing_events e
join public.subscriptions s on s.asaas_subscription_id = e.payload #>> '{payment,subscription}'
where e.event in ('PAYMENT_CONFIRMED', 'PAYMENT_RECEIVED')
  and nullif(e.payload #>> '{payment,id}', '') is not null
  and s.current_period_end is not null
order by e.payload #>> '{payment,id}', e.processed_at
on conflict (payment_id) do nothing;

create schema if not exists billing_private;
revoke all on schema billing_private from public, anon, authenticated;

create function billing_private.apply_feature_payment(p_event_id text, p_payment jsonb)
returns text language plpgsql security definer set search_path = '' as $$
declare
  f public.job_featurings;
  v_until timestamptz;
begin
  select * into f from public.job_featurings
    where asaas_payment_id = p_payment ->> 'id' for update;
  if not found then return 'pending'; end if;
  if f.status = 'paid' then return 'processed'; end if;
  select greatest(coalesce(featured_until, now()), now()) + make_interval(days => f.days)
    into strict v_until from public.jobs where id = f.job_id for update;
  insert into public.billing_payment_receipts (payment_id, product, event_id, expires_at)
    values (p_payment ->> 'id', 'job_feature', p_event_id, v_until)
    on conflict (payment_id) do nothing;
  if not found then return 'processed'; end if;
  update public.jobs set featured_until = v_until where id = f.job_id;
  update public.job_featurings set status = 'paid', paid_at = now() where id = f.id;
  perform public.notify(f.user_id, 'system', 'Vaga patrocinada ativa',
    'Pagamento confirmado. Sua vaga já está no espaço de vagas patrocinadas do mural.',
    jsonb_build_object('job_id', f.job_id, 'route', '/jobs/' || f.job_id));
  return 'processed';
end;
$$;

create function billing_private.apply_subscription_payment(p_event_id text, p_payment jsonb)
returns text language plpgsql security definer set search_path = '' as $$
declare
  s public.subscriptions;
  v_until timestamptz := now() + interval '33 days';
begin
  select * into s from public.subscriptions
    where asaas_subscription_id = p_payment ->> 'subscription' for update;
  if not found then return 'pending'; end if;
  perform 1 from public.profiles where id = s.user_id for update;
  if not found then raise exception 'PROFILE_NOT_FOUND'; end if;
  insert into public.billing_payment_receipts (payment_id, product, event_id, expires_at)
    values (p_payment ->> 'id', 'pro_monthly', p_event_id, v_until)
    on conflict (payment_id) do nothing;
  if not found then return 'processed'; end if;
  update public.subscriptions set status = 'active',
    current_period_end = greatest(current_period_end, v_until) where id = s.id;
  update public.profiles set plan = 'pro',
    plan_expires_at = greatest(plan_expires_at, v_until) where id = s.user_id;
  perform public.notify(s.user_id, 'system', 'Plano Pro ativo 🎉',
    'Mais propostas, modelos, organização de clientes e estatísticas liberados. Obrigado por apoiar o Trabalhei!',
    jsonb_build_object('route', '/plans'));
  return 'processed';
end;
$$;

-- Mantém a regra atual de cancelamento/atraso. Estorno de destaque é outra correção.
create function billing_private.apply_subscription_status(p_payload jsonb)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_event text := p_payload ->> 'event';
  v_subscription text := coalesce(p_payload #>> '{payment,subscription}', p_payload #>> '{subscription,id}');
  s public.subscriptions;
begin
  if nullif(v_subscription, '') is null then return 'ignored'; end if;
  select * into s from public.subscriptions where asaas_subscription_id = v_subscription for update;
  if not found then return 'pending'; end if;
  update public.subscriptions set status = case when v_event = 'PAYMENT_OVERDUE'
    then 'overdue' else 'cancelled' end where id = s.id;
  if v_event in ('PAYMENT_REFUNDED', 'PAYMENT_CHARGEBACK_REQUESTED') then
    update public.profiles set plan = 'free', plan_expires_at = null where id = s.user_id;
    if not found then raise exception 'PROFILE_NOT_FOUND'; end if;
  end if;
  return 'processed';
end;
$$;

revoke all on all functions in schema billing_private from public, anon, authenticated;
