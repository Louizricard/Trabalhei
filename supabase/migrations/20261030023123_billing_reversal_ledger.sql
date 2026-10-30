alter table public.billing_payment_receipts
  add column subscription_id uuid references public.subscriptions(id) on delete set null,
  add column pro_user_id uuid references public.profiles(id) on delete set null,
  add column pro_original_expires_at timestamptz,
  add column benefit_applied boolean not null default true,
  add column reversal_state text not null default 'none'
    check(reversal_state in('none','held','awaiting','restored','refunded')),
  add column reversal_at timestamptz,
  add column reversal_event_id text references public.billing_events(id) on delete set null;
create index billing_receipts_subscription_idx on public.billing_payment_receipts(subscription_id);
create index billing_receipts_pro_user_idx on public.billing_payment_receipts(pro_user_id);
create index billing_receipts_reversal_idx on public.billing_payment_receipts(reversal_event_id);

update public.billing_payment_receipts r set subscription_id=s.id,pro_user_id=s.user_id,
  pro_original_expires_at=least(r.expires_at,r.applied_at+interval '33 days')
from public.billing_events e join public.subscriptions s
  on s.asaas_subscription_id=e.payload#>>'{payment,subscription}'
where r.product='pro_monthly' and r.event_id=e.id;
do $$ begin
  if exists(select 1 from public.billing_payment_receipts where product='pro_monthly'
    and pro_user_id is null and expires_at>now()) then raise exception 'PRO_RECEIPT_REFERENCE_UNKNOWN'; end if;
end $$;
update public.billing_payment_receipts set reversal_state='refunded' where revoked_at is not null;
update public.billing_payment_receipts r set benefit_applied=false from public.job_featurings f
  where r.payment_id=f.asaas_payment_id and r.revoked_at is not null and f.paid_at is null;

-- Concessões gratuitas têm prazo próprio: um estorno não cancela um cupom/admin.
create table public.billing_pro_grants(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  expires_at timestamptz,
  origin text not null check(origin in('legacy','grant')),
  created_at timestamptz not null default now()
);
create index billing_pro_grants_user_idx on public.billing_pro_grants(user_id);
alter table public.billing_pro_grants enable row level security;
revoke all on public.billing_pro_grants from public,anon,authenticated;
grant all on public.billing_pro_grants to service_role;
insert into public.billing_pro_grants(user_id,expires_at,origin)
select p.id,p.plan_expires_at,'legacy' from public.profiles p where p.plan='pro'
  and (p.plan_expires_at is null or p.plan_expires_at>coalesce((select max(r.pro_original_expires_at)
    from public.billing_payment_receipts r where r.pro_user_id=p.id and r.revoked_at is null),'-infinity'));

create function billing_private.refresh_pro(p_user uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_until timestamptz; v_unlimited boolean;
begin
  perform 1 from public.profiles where id=p_user for update;
  select exists(select 1 from public.billing_pro_grants where user_id=p_user and expires_at is null)
    into v_unlimited;
  select max(expires_at) into v_until from (
    select pro_original_expires_at expires_at from public.billing_payment_receipts where pro_user_id=p_user
      and product='pro_monthly' and revoked_at is null and benefit_applied
    union all select expires_at from public.billing_pro_grants where user_id=p_user) credits;
  update public.profiles set plan=case when deleted_at is null and (v_unlimited or v_until>now()) then 'pro' else 'free' end,
    plan_expires_at=case when deleted_at is null and not v_unlimited and v_until>now() then v_until end where id=p_user;
end;
$$;
revoke all on function billing_private.refresh_pro(uuid) from public,anon,authenticated,service_role;

create or replace function public.grant_pro(p_user uuid,p_days integer,p_reason text)
returns timestamptz language plpgsql security definer set search_path='' as $$
declare v_until timestamptz;
begin
  if p_days<=0 or p_days is null then raise exception 'INVALID_GRANT_DAYS'; end if;
  select greatest(coalesce(plan_expires_at,now()),now())+make_interval(days=>p_days)
    into strict v_until from public.profiles where id=p_user and deleted_at is null for update;
  insert into public.billing_pro_grants(user_id,expires_at,origin) values(p_user,v_until,'grant');
  perform billing_private.refresh_pro(p_user);
  perform public.notify(p_user,'system','Plano Pro ativo',
    p_reason||' Seu Pro vale até '||to_char(v_until at time zone 'America/Sao_Paulo','DD/MM/YYYY')||'.',
    jsonb_build_object('route','/plans'));
  return v_until;
end;
$$;
revoke all on function public.grant_pro(uuid,integer,text) from public,anon,authenticated;
grant execute on function public.grant_pro(uuid,integer,text) to service_role;
