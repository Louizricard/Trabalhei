-- Cupons de desconto (ex.: promoções de lançamento). O desconto vale para a
-- primeira cobrança: o 1º mês do Pro ou o destaque de projeto. Cupom de 100%
-- libera o produto sem passar pelo Asaas. Os códigos não são listáveis por
-- usuários (evita adivinhação); a validação é pela função quote_price.
-- Ver docs/monetizacao.md.

create table public.coupons (
  code text primary key check (code ~ '^[A-Z0-9_-]{3,30}$'),
  description text check (description is null or char_length(description) <= 200),
  product text not null check (product in ('pro_monthly', 'job_feature', 'any')),
  percent_off integer check (percent_off between 1 and 100),
  amount_off numeric(10, 2) check (amount_off > 0),
  max_redemptions integer check (max_redemptions is null or max_redemptions > 0),
  redemptions_count integer not null default 0,
  per_user_limit integer not null default 1 check (per_user_limit > 0),
  valid_from timestamptz not null default now(),
  valid_until timestamptz,
  active boolean not null default true,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint coupons_one_discount check ((percent_off is null) <> (amount_off is null))
);
alter table public.coupons enable row level security;
revoke all on public.coupons from anon, authenticated;

create table public.coupon_redemptions (
  id uuid primary key default gen_random_uuid(),
  code text not null references public.coupons (code) on update cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  product text not null,
  original_price numeric(10, 2) not null,
  final_price numeric(10, 2) not null,
  reference text,
  created_at timestamptz not null default now()
);
create index coupon_redemptions_user_idx on public.coupon_redemptions (user_id, code);
alter table public.coupon_redemptions enable row level security;
create policy coupon_redemptions_read_own on public.coupon_redemptions
  for select to authenticated using (user_id = (select auth.uid()));
revoke insert, update, delete on public.coupon_redemptions from anon, authenticated;

-- Preço com o cupom aplicado. Levanta um código de erro se não valer.
create function public.coupon_price(p_user uuid, p_product text, p_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_code text := upper(trim(coalesce(p_code, '')));
  v_price numeric;
  c public.coupons;
  v_final numeric;
begin
  select price into v_price from public.billing_products where code = p_product and active;
  if v_price is null then raise exception 'PRODUCT_UNAVAILABLE'; end if;
  if v_code = '' then
    return jsonb_build_object('price', v_price, 'final_price', v_price, 'discount', 0);
  end if;

  select * into c from public.coupons where code = v_code;
  if not found or not c.active then raise exception 'COUPON_INVALID'; end if;
  if c.product <> 'any' and c.product <> p_product then raise exception 'COUPON_NOT_FOR_PRODUCT'; end if;
  if now() < c.valid_from or (c.valid_until is not null and now() > c.valid_until) then
    raise exception 'COUPON_EXPIRED';
  end if;
  if c.max_redemptions is not null and c.redemptions_count >= c.max_redemptions then
    raise exception 'COUPON_EXHAUSTED';
  end if;
  if (select count(*) from public.coupon_redemptions where code = v_code and user_id = p_user)
      >= c.per_user_limit then
    raise exception 'COUPON_ALREADY_USED';
  end if;

  v_final := greatest(round(case
    when c.percent_off is not null then v_price * (100 - c.percent_off) / 100
    else v_price - c.amount_off end, 2), 0);
  -- O Asaas não emite cobrança abaixo de R$ 5,00: um desconto que deixe o
  -- valor entre zero e isso para em R$ 5,00 (o app já mostra o valor final).
  if v_final > 0 and v_final < 5 then v_final := least(5, v_price); end if;
  return jsonb_build_object(
    'price', v_price, 'final_price', v_final, 'discount', v_price - v_final,
    'code', v_code, 'description', c.description
  );
end;
$$;
revoke all on function public.coupon_price(uuid, text, text) from public, anon, authenticated;

-- Para o app: mostra o preço final antes de pagar.
create function public.quote_price(p_product text, p_code text default null)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$ select public.coupon_price(auth.uid(), p_product, p_code) $$;
revoke all on function public.quote_price(text, text) from public, anon;
grant execute on function public.quote_price(text, text) to authenticated;

-- Para as Edge Functions (service_role): valida e registra o uso do cupom de
-- forma atômica (trava a linha do cupom para não passar do limite).
create function public.redeem_coupon(p_user uuid, p_product text, p_code text, p_reference text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text := upper(trim(coalesce(p_code, '')));
  v_quote jsonb;
begin
  if v_code = '' then return public.coupon_price(p_user, p_product, null); end if;
  perform 1 from public.coupons where code = v_code for update;
  v_quote := public.coupon_price(p_user, p_product, v_code);
  update public.coupons set redemptions_count = redemptions_count + 1 where code = v_code;
  insert into public.coupon_redemptions (code, user_id, product, original_price, final_price, reference)
    values (v_code, p_user, p_product, (v_quote ->> 'price')::numeric,
            (v_quote ->> 'final_price')::numeric, p_reference);
  return v_quote;
end;
$$;
revoke all on function public.redeem_coupon(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.redeem_coupon(uuid, text, text, text) to service_role;

-- Desfaz o uso do cupom se a cobrança não chegou a ser criada.
create function public.release_coupon(p_reference text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.coupon_redemptions;
begin
  delete from public.coupon_redemptions where reference = p_reference returning * into r;
  if found then
    update public.coupons set redemptions_count = greatest(redemptions_count - 1, 0)
      where code = r.code;
  end if;
end;
$$;
revoke all on function public.release_coupon(text) from public, anon, authenticated;
grant execute on function public.release_coupon(text) to service_role;

-- ---------------------------------------------------------------- Admin
create function public.admin_list_coupons()
returns setof public.coupons
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  return query select * from public.coupons order by created_at desc;
end;
$$;

create function public.admin_create_coupon(
  p_code text, p_product text, p_percent_off integer, p_amount_off numeric,
  p_max_redemptions integer, p_valid_until timestamptz, p_description text,
  p_per_user_limit integer default 1
)
returns public.coupons
language plpgsql
security definer
set search_path = ''
as $$
declare
  c public.coupons;
begin
  perform public.require_admin();
  insert into public.coupons (code, product, percent_off, amount_off, max_redemptions,
                              valid_until, description, per_user_limit, created_by)
  values (upper(trim(p_code)), p_product, p_percent_off, p_amount_off, p_max_redemptions,
          p_valid_until, nullif(trim(coalesce(p_description, '')), ''),
          coalesce(p_per_user_limit, 1), auth.uid())
  returning * into c;
  insert into public.moderation_actions (admin_id, action, target_type, target_id, reason)
    values (auth.uid(), 'create_coupon', 'coupon', gen_random_uuid(), c.code);
  return c;
end;
$$;

create function public.admin_set_coupon_active(p_code text, p_active boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  update public.coupons set active = p_active where code = upper(trim(p_code));
  if not found then raise exception 'COUPON_INVALID'; end if;
end;
$$;

revoke all on function public.admin_list_coupons() from public, anon;
revoke all on function public.admin_create_coupon(text, text, integer, numeric, integer, timestamptz, text, integer) from public, anon;
revoke all on function public.admin_set_coupon_active(text, boolean) from public, anon;
grant execute on function public.admin_list_coupons() to authenticated;
grant execute on function public.admin_create_coupon(text, text, integer, numeric, integer, timestamptz, text, integer) to authenticated;
grant execute on function public.admin_set_coupon_active(text, boolean) to authenticated;

-- Pro concedido sem cobrança (cupom de 100%): mesmo efeito do webhook pago.
create function public.grant_pro(p_user uuid, p_days integer, p_reason text)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_until timestamptz;
begin
  update public.profiles
    set plan = 'pro',
        plan_expires_at = greatest(coalesce(plan_expires_at, now()), now()) + make_interval(days => p_days)
    where id = p_user
    returning plan_expires_at into v_until;
  perform public.notify(
    p_user, 'system', 'Plano Pro ativo',
    p_reason || ' Seu Pro vale até ' || to_char(v_until at time zone 'America/Sao_Paulo', 'DD/MM/YYYY') || '.',
    jsonb_build_object('route', '/plans')
  );
  return v_until;
end;
$$;
revoke all on function public.grant_pro(uuid, integer, text) from public, anon, authenticated;
grant execute on function public.grant_pro(uuid, integer, text) to service_role;
