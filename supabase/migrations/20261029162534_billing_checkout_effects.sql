alter table public.job_featurings drop constraint job_featurings_amount_check;
alter table public.job_featurings add constraint job_featurings_amount_check
  check (amount>0 or (amount=0 and asaas_payment_id like 'coupon:%' and status='paid'));

create function public.price_billing_checkout(p_id uuid,p_token uuid)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare c public.billing_checkouts; q jsonb; v_days integer; v_until timestamptz;
begin
  c:=billing_private.lock_checkout(p_id,p_token);
  if c.quote is not null then return jsonb_build_object('quote',c.quote,'result',c.result); end if;
  q:=public.redeem_coupon(c.user_id,c.product,nullif(c.coupon_code,''),
    case when c.product='pro_monthly' then 'sub:' else 'feature:' end || c.id);
  select period_days into strict v_days from public.billing_products where code=c.product and active;
  q:=q || jsonb_build_object('days',v_days);
  if (q->>'final_price')::numeric=0 then
    if c.product='pro_monthly' then
      v_until:=public.grant_pro(c.user_id,v_days,'Cupom aplicado no checkout.');
    else
      update public.jobs set featured_until=greatest(coalesce(featured_until,now()),now())+make_interval(days=>v_days)
        where id=c.job_id and client_id=c.user_id and status='open' returning featured_until into v_until;
      if not found then raise exception 'JOB_NOT_OPEN'; end if;
      insert into public.job_featurings(id,job_id,user_id,asaas_payment_id,days,amount,status,paid_at)
        values(c.id,c.job_id,c.user_id,'coupon:'||c.coupon_code||':'||c.id,v_days,0,'paid',now());
    end if;
    c.result:=jsonb_build_object('granted',true,'until',v_until);
  end if;
  update public.billing_checkouts set quote=q,result=c.result where id=c.id;
  return jsonb_build_object('quote',q,'result',c.result);
end;
$$;
revoke all on function public.price_billing_checkout(uuid,uuid) from public,anon,authenticated;
grant execute on function public.price_billing_checkout(uuid,uuid) to service_role;

-- A reserva, a associação local e o replay do webhook participam da transação.
-- Repetir a associação é seguro; conflito de IDs não é sobrescrito.
create function public.link_billing_checkout(p_id uuid,p_token uuid,p_provider text)
returns void language plpgsql security invoker set search_path='' as $$
declare c public.billing_checkouts;
begin
  c:=billing_private.lock_checkout(p_id,p_token);
  if c.quote is null or (c.quote->>'final_price')::numeric<=0 then raise exception 'CHECKOUT_NOT_PRICED'; end if;
  if c.product='pro_monthly' then
    insert into public.subscriptions(id,user_id,asaas_subscription_id,billing_type,status)
      values(c.id,c.user_id,p_provider,c.billing_type,'pending') on conflict(id) do nothing;
    if not exists(select 1 from public.subscriptions where id=c.id and asaas_subscription_id=p_provider) then
      raise exception 'CHECKOUT_LINK_CONFLICT'; end if;
  else
    insert into public.job_featurings(id,job_id,user_id,asaas_payment_id,days,amount)
      values(c.id,c.job_id,c.user_id,p_provider,(c.quote->>'days')::integer,(c.quote->>'final_price')::numeric)
      on conflict(id) do nothing;
    if not exists(select 1 from public.job_featurings where id=c.id and asaas_payment_id=p_provider) then
      raise exception 'CHECKOUT_LINK_CONFLICT'; end if;
  end if;
end;
$$;
create function public.finish_billing_checkout(p_id uuid,p_token uuid,p_result jsonb)
returns void language plpgsql security invoker set search_path='' as $$
begin
  perform billing_private.lock_checkout(p_id,p_token);
  update public.billing_checkouts set result=p_result where id=p_id;
end;
$$;
revoke all on function public.link_billing_checkout(uuid,uuid,text),public.finish_billing_checkout(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.link_billing_checkout(uuid,uuid,text),public.finish_billing_checkout(uuid,uuid,jsonb) to service_role;
