-- Compras pelo Google Play Billing (app Android): Pro mensal (assinatura) e Destaque (produto
-- consumível). A Edge Function play-billing confere cada compra na API do Google Play e chama as
-- funções abaixo com a service_role. Detalhes: docs/play-billing.md.
-- Volta: rollbacks/20261120172358_play_billing_down.sql.

create table public.play_purchases(
  purchase_token text primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  product text not null check(product in('pro_monthly','job_feature')),
  order_id text,
  job_id uuid references public.jobs(id) on delete set null,
  -- Assinatura: active (renova), cancelled (não renova, vale até expires_at), expired, pending.
  -- Destaque: applied. Ambos: refunded (estornada/anulada pelo Google).
  state text not null check(state in('pending','active','cancelled','expired','applied','refunded')),
  expires_at timestamptz,
  feature_starts_at timestamptz,
  feature_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index play_purchases_user_idx on public.play_purchases(user_id);
create index play_purchases_job_idx on public.play_purchases(job_id);
create trigger play_purchases_touch before update on public.play_purchases
  for each row execute function public.touch_updated_at();
alter table public.play_purchases enable row level security;
create policy play_purchases_select_own on public.play_purchases
  for select to authenticated using (user_id=(select auth.uid()));
revoke all on public.play_purchases from public,anon,authenticated;
grant select on public.play_purchases to authenticated;
grant all on public.play_purchases to service_role;

-- Pro passa a contar também as assinaturas do Google Play ativas ou canceladas dentro do prazo.
create or replace function billing_private.refresh_pro(p_user uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_until timestamptz; v_unlimited boolean;
begin
  perform 1 from public.profiles where id=p_user for update;
  select exists(select 1 from public.billing_pro_grants where user_id=p_user and expires_at is null)
    into v_unlimited;
  select max(expires_at) into v_until from (
    select pro_original_expires_at expires_at from public.billing_payment_receipts where pro_user_id=p_user
      and product='pro_monthly' and revoked_at is null and benefit_applied
    union all select expires_at from public.billing_pro_grants where user_id=p_user
    union all select expires_at from public.play_purchases where user_id=p_user
      and product='pro_monthly' and state in('active','cancelled')) credits;
  update public.profiles set plan=case when deleted_at is null and (v_unlimited or v_until>now()) then 'pro' else 'free' end,
    plan_expires_at=case when deleted_at is null and not v_unlimited and v_until>now() then v_until end where id=p_user;
end;
$$;
revoke all on function billing_private.refresh_pro(uuid) from public,anon,authenticated,service_role;

-- Estado de uma assinatura conferida no Google. Idempotente: reaplicar o mesmo estado não muda nada.
-- Um token pertence para sempre ao primeiro usuário que o registrou.
create function public.apply_play_subscription(p_user uuid,p_token text,p_order text,p_state text,p_expires timestamptz)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_owner uuid; v_old text; v_plan_until timestamptz;
begin
  if p_state not in('pending','active','cancelled','expired') then raise exception 'INVALID_PLAY_STATE'; end if;
  if p_state in('active','cancelled') and p_expires is null then raise exception 'INVALID_PLAY_STATE'; end if;
  perform 1 from public.profiles where id=p_user and deleted_at is null;
  if not found then raise exception 'ACCOUNT_UNAVAILABLE'; end if;
  select user_id,state into v_owner,v_old from public.play_purchases where purchase_token=p_token for update;
  if found and v_owner<>p_user then raise exception 'PURCHASE_OWNED_BY_OTHER'; end if;
  if found and v_old='refunded' then
    return jsonb_build_object('state','refunded');
  end if;
  insert into public.play_purchases(purchase_token,user_id,product,order_id,state,expires_at)
    values(p_token,p_user,'pro_monthly',p_order,p_state,p_expires)
  on conflict(purchase_token) do update set state=excluded.state,expires_at=excluded.expires_at,
    order_id=coalesce(excluded.order_id,public.play_purchases.order_id)
  where public.play_purchases.product='pro_monthly';
  if not found then raise exception 'PURCHASE_PRODUCT_CONFLICT'; end if;
  perform billing_private.refresh_pro(p_user);
  select plan_expires_at into v_plan_until from public.profiles where id=p_user;
  if p_state='active' and v_old is distinct from 'active' then
    perform public.notify(p_user,'system','Plano Pro ativo',
      'Assinatura confirmada pelo Google Play. Aproveite os recursos do Pro.',
      jsonb_build_object('route','/plans'));
  end if;
  return jsonb_build_object('state',p_state,'pro_until',v_plan_until);
end;
$$;

-- Destaque comprado no Google Play. O job_id vem do próprio Google (obfuscatedProfileId), não do app.
create function public.apply_play_feature(p_user uuid,p_token text,p_order text,p_job uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_owner uuid; v_state text; v_until timestamptz; v_start timestamptz; v_days int; j public.jobs;
begin
  select user_id,state,feature_until into v_owner,v_state,v_until
    from public.play_purchases where purchase_token=p_token for update;
  if found then
    if v_owner<>p_user then raise exception 'PURCHASE_OWNED_BY_OTHER'; end if;
    return jsonb_build_object('state',v_state,'featured_until',v_until);
  end if;
  select * into j from public.jobs where id=p_job for update;
  if not found or j.client_id<>p_user then raise exception 'JOB_NOT_FOUND'; end if;
  perform 1 from public.profiles where id=p_user and deleted_at is null;
  if not found then raise exception 'ACCOUNT_UNAVAILABLE'; end if;
  select coalesce(period_days,7) into v_days from public.billing_products where code='job_feature';
  v_start:=greatest(coalesce(j.featured_until,now()),now());
  v_until:=v_start+make_interval(days=>coalesce(v_days,7));
  -- Vaga já fechada: a compra fica registrada (o Google cobrou), sem destaque a aplicar.
  if j.status<>'open' then
    insert into public.play_purchases(purchase_token,user_id,product,order_id,job_id,state)
      values(p_token,p_user,'job_feature',p_order,p_job,'applied');
    return jsonb_build_object('state','applied','featured_until',null);
  end if;
  insert into public.play_purchases(purchase_token,user_id,product,order_id,job_id,state,feature_starts_at,feature_until)
    values(p_token,p_user,'job_feature',p_order,p_job,'applied',v_start,v_until);
  update public.jobs set featured_until=v_until where id=p_job;
  perform public.notify(p_user,'system','Vaga patrocinada ativa',
    'Compra confirmada pelo Google Play. Sua vaga já está no espaço de vagas patrocinadas do mural.',
    jsonb_build_object('job_id',p_job,'route','/jobs/'||p_job));
  return jsonb_build_object('state','applied','featured_until',v_until);
end;
$$;

-- Compra anulada/estornada pelo Google (voided purchase). Remove o benefício restante.
create function public.revoke_play_purchase(p_token text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.play_purchases; v_current timestamptz; v_remove interval;
begin
  select * into p from public.play_purchases where purchase_token=p_token for update;
  if not found then return jsonb_build_object('state','unknown'); end if;
  if p.state='refunded' then return jsonb_build_object('state','refunded'); end if;
  update public.play_purchases set state='refunded' where purchase_token=p_token;
  if p.product='pro_monthly' then
    perform billing_private.refresh_pro(p.user_id);
  elsif p.feature_until is not null and p.job_id is not null then
    select featured_until into v_current from public.jobs where id=p.job_id for update;
    v_remove:=least(greatest(p.feature_until-greatest(now(),p.feature_starts_at),interval '0'),
      greatest(coalesce(v_current,now())-now(),interval '0'));
    if v_remove>interval '0' then
      update public.jobs set featured_until=greatest(now(),v_current-v_remove) where id=p.job_id;
    end if;
  end if;
  return jsonb_build_object('state','refunded','user_id',p.user_id);
end;
$$;

revoke all on function public.apply_play_subscription(uuid,text,text,text,timestamptz) from public,anon,authenticated;
revoke all on function public.apply_play_feature(uuid,text,text,uuid) from public,anon,authenticated;
revoke all on function public.revoke_play_purchase(text) from public,anon,authenticated;
grant execute on function public.apply_play_subscription(uuid,text,text,text,timestamptz) to service_role;
grant execute on function public.apply_play_feature(uuid,text,text,uuid) to service_role;
grant execute on function public.revoke_play_purchase(text) to service_role;
