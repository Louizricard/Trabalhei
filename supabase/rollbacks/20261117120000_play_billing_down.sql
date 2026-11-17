-- Volta de 20261117120000_play_billing. Recusa se já houver compra do Google Play registrada:
-- apagar a tabela perderia o vínculo entre o que o Google cobrou e o benefício concedido.
do $$ begin
  if exists(select 1 from public.play_purchases) then raise exception 'PLAY_PURCHASES_PRESENT'; end if;
end $$;

drop function public.revoke_play_purchase(text);
drop function public.apply_play_feature(uuid,text,text,uuid);
drop function public.apply_play_subscription(uuid,text,text,text,timestamptz);

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
    union all select expires_at from public.billing_pro_grants where user_id=p_user) credits;
  update public.profiles set plan=case when deleted_at is null and (v_unlimited or v_until>now()) then 'pro' else 'free' end,
    plan_expires_at=case when deleted_at is null and not v_unlimited and v_until>now() then v_until end where id=p_user;
end;
$$;
revoke all on function billing_private.refresh_pro(uuid) from public,anon,authenticated,service_role;

drop table public.play_purchases;
