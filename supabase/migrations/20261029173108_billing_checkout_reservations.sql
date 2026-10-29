-- Só o servidor coordena checkouts. Não guarda CPF, cartão, e-mail nem QR Code.
create table if not exists public.billing_checkout_locks (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  token uuid not null,
  expires_at timestamptz not null
);
create table if not exists public.billing_checkouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  product text not null references public.billing_products(code),
  job_id uuid references public.jobs(id) on delete cascade,
  billing_type text not null check (billing_type in ('PIX','CREDIT_CARD')),
  coupon_code text not null default '',
  quote jsonb,
  result jsonb,
  closed boolean not null default false,
  created_at timestamptz not null default now(),
  check ((product='job_feature') = (job_id is not null))
);
create unique index if not exists billing_checkouts_open_scope on public.billing_checkouts
  (user_id,product,coalesce(job_id,'00000000-0000-0000-0000-000000000000'::uuid)) where not closed;
create index if not exists billing_checkouts_job on public.billing_checkouts(job_id) where job_id is not null;
create table if not exists public.billing_checkout_steps (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  step_key text not null,
  provider_id text,
  created_at timestamptz not null default now(),
  unique(user_id,step_key)
);
create table if not exists public.billing_checkout_requests (
  user_id uuid not null references public.profiles(id) on delete cascade,
  request_id uuid not null,
  checkout_id uuid not null references public.billing_checkouts(id),
  primary key(user_id,request_id)
);
create index if not exists billing_checkout_requests_checkout on public.billing_checkout_requests(checkout_id);
alter table public.billing_checkout_locks enable row level security;
alter table public.billing_checkouts enable row level security;
alter table public.billing_checkout_steps enable row level security;
alter table public.billing_checkout_requests enable row level security;
revoke all on public.billing_checkout_requests from public,anon,authenticated;
grant all on public.billing_checkout_requests to service_role;
revoke all on public.billing_checkout_locks,public.billing_checkouts,public.billing_checkout_steps from public,anon,authenticated;
grant all on public.billing_checkout_locks,public.billing_checkouts,public.billing_checkout_steps to service_role;
grant usage on schema billing_private to service_role;

-- Não basta a unicidade do ID remoto: o usuário só pode ter uma recorrência aberta.
-- A migration falha se o histórico exigir conciliação; não cancela cobranças existentes.
create unique index subscriptions_one_open_per_user on public.subscriptions(user_id)
  where status in ('pending','active','overdue');
create unique index job_featurings_one_pending_per_job on public.job_featurings(job_id)
  where status='pending';

create function public.claim_billing_checkout(
  p_user uuid,p_product text,p_job uuid,p_billing_type text,p_coupon text,p_request uuid default null
) returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_token uuid:=gen_random_uuid(); c public.billing_checkouts; v_code text:=upper(trim(coalesce(p_coupon,'')));
begin
  if p_billing_type not in ('PIX','CREDIT_CARD') then raise exception 'INVALID_METHOD'; end if;
  if p_product='job_feature' and not exists (
    select 1 from public.jobs where id=p_job and client_id=p_user and status='open'
  ) then raise exception 'JOB_NOT_OPEN'; end if;
  insert into public.billing_checkout_locks values(p_user,v_token,now()+interval '90 seconds')
    on conflict(user_id) do update set token=excluded.token,expires_at=excluded.expires_at
    where public.billing_checkout_locks.expires_at < now();
  if not found then raise exception 'CHECKOUT_BUSY'; end if;
  if p_request is not null then
    select bc.* into c from public.billing_checkouts bc join public.billing_checkout_requests r on r.checkout_id=bc.id
      where r.user_id=p_user and r.request_id=p_request;
    if found then
      if c.product<>p_product or c.job_id is distinct from p_job or c.billing_type<>p_billing_type or c.coupon_code<>v_code then
        raise exception 'CHECKOUT_REQUEST_CONFLICT';
      end if;
      return jsonb_build_object('checkout',to_jsonb(c),'token',v_token);
    end if;
  end if;
  select * into c from public.billing_checkouts where user_id=p_user and product=p_product
    and job_id is not distinct from p_job and not closed for update;
  if c.result is not null and p_product='job_feature' and exists (
    select 1 from public.job_featurings where asaas_payment_id=c.result->>'payment_id' and status<>'pending'
  ) or c.result is not null and p_product='pro_monthly' and exists (
    select 1 from public.subscriptions where asaas_subscription_id=c.result->>'subscription_id' and status='cancelled'
  ) then
    update public.billing_checkouts set closed=true where id=c.id; c:=null;
  end if;
  if c.id is not null and (c.billing_type<>p_billing_type or c.coupon_code<>v_code) then
    if c.result is null then
      if exists(select 1 from public.billing_checkout_steps where user_id=p_user
        and step_key in (c.id||':subscription',c.id||':payment')) then
        raise exception 'CHECKOUT_RECOVERY_REQUIRED';
      end if;
      -- Sem POST financeiro reservado, uma validação falhou antes de cobrar.
      perform public.release_coupon(case when c.product='pro_monthly' then 'sub:' else 'feature:' end || c.id);
    end if;
    update public.billing_checkouts set closed=true where id=c.id; c:=null;
  end if;
  if c.id is null then
    insert into public.billing_checkouts(user_id,product,job_id,billing_type,coupon_code)
      values(p_user,p_product,p_job,p_billing_type,v_code) returning * into c;
  end if;
  if p_request is not null then insert into public.billing_checkout_requests values(p_user,p_request,c.id); end if;
  return jsonb_build_object('checkout',to_jsonb(c),'token',v_token);
end;
$$;
revoke all on function public.claim_billing_checkout(uuid,text,uuid,text,text,uuid) from public,anon,authenticated;
grant execute on function public.claim_billing_checkout(uuid,text,uuid,text,text,uuid) to service_role;

create function billing_private.lock_checkout(p_id uuid,p_token uuid)
returns public.billing_checkouts language plpgsql security invoker set search_path='' as $$
declare c public.billing_checkouts;
begin
  select * into strict c from public.billing_checkouts where id=p_id;
  perform 1 from public.billing_checkout_locks where user_id=c.user_id and token=p_token
    and expires_at>now() for update;
  if not found then raise exception 'CHECKOUT_LEASE_LOST'; end if;
  select * into strict c from public.billing_checkouts where id=p_id for update;
  return c;
end;
$$;
revoke all on function billing_private.lock_checkout(uuid,uuid) from public,anon,authenticated;
grant execute on function billing_private.lock_checkout(uuid,uuid) to service_role;

create function public.release_billing_checkout(p_id uuid,p_token uuid)
returns void language sql security invoker set search_path='' as $$
  delete from public.billing_checkout_locks l using public.billing_checkouts c
    where c.id=p_id and l.user_id=c.user_id and l.token=p_token;
$$;
revoke all on function public.release_billing_checkout(uuid,uuid) from public,anon,authenticated;
grant execute on function public.release_billing_checkout(uuid,uuid) to service_role;

-- Uma reserva de POST nunca expira. Após timeout só há leitura/conciliação,
-- mesmo se a lease do worker vencer. externalReference NÃO é chave única no Asaas.
create function public.reserve_billing_step(p_id uuid,p_token uuid,p_key text)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare c public.billing_checkouts; s public.billing_checkout_steps; v_fresh boolean;
begin
  c:=billing_private.lock_checkout(p_id,p_token);
  insert into public.billing_checkout_steps(user_id,step_key) values(c.user_id,p_key)
    on conflict(user_id,step_key) do nothing returning * into s;
  v_fresh:=found;
  if not v_fresh then select * into strict s from public.billing_checkout_steps
    where user_id=c.user_id and step_key=p_key; end if;
  return jsonb_build_object('fresh',v_fresh,'step',to_jsonb(s));
end;
$$;
create function public.record_billing_step(p_step uuid,p_provider text)
returns void language plpgsql security invoker set search_path='' as $$
begin
  if coalesce(p_provider,'')='' then raise exception 'PROVIDER_ID_REQUIRED'; end if;
  update public.billing_checkout_steps set provider_id=p_provider
    where id=p_step and (provider_id is null or provider_id=p_provider);
  if not found then raise exception 'PROVIDER_ID_CONFLICT'; end if;
end;
$$;
revoke all on function public.reserve_billing_step(uuid,uuid,text),public.record_billing_step(uuid,text) from public,anon,authenticated;
grant execute on function public.reserve_billing_step(uuid,uuid,text),public.record_billing_step(uuid,text) to service_role;

-- Só uma rejeição HTTP definitiva (400/422) libera o POST; timeout/5xx nunca.
create function public.reject_billing_step(p_id uuid,p_token uuid,p_step uuid)
returns void language plpgsql security invoker set search_path='' as $$
declare c public.billing_checkouts;
begin
  c:=billing_private.lock_checkout(p_id,p_token);
  delete from public.billing_checkout_steps where id=p_step and user_id=c.user_id and provider_id is null;
end;
$$;
revoke all on function public.reject_billing_step(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.reject_billing_step(uuid,uuid,uuid) to service_role;
