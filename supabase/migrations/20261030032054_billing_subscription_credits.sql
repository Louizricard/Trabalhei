create or replace function billing_private.apply_subscription_payment(p_event_id text,p_payment jsonb)
returns text language plpgsql security definer set search_path='' as $$
declare s public.subscriptions; v_until timestamptz:=now()+interval '33 days';
begin
  select * into s from public.subscriptions where asaas_subscription_id=p_payment->>'subscription';
  if not found then return 'pending'; end if;
  perform 1 from public.profiles where id=s.user_id for update;
  perform 1 from public.subscriptions where id=s.id for update;
  insert into public.billing_payment_receipts
    (payment_id,product,event_id,expires_at,subscription_id,pro_user_id,pro_original_expires_at)
    values(p_payment->>'id','pro_monthly',p_event_id,v_until,s.id,s.user_id,v_until)
    on conflict(payment_id) do nothing;
  if not found then return 'processed'; end if;
  update public.subscriptions set status=case when status='cancelled' then status else 'active' end,
    current_period_end=greatest(current_period_end,v_until) where id=s.id;
  perform billing_private.refresh_pro(s.user_id);
  perform public.notify(s.user_id,'system','Plano Pro ativo 🎉',
    'Pagamento confirmado. Seu período Pro foi registrado.',jsonb_build_object('route','/plans'));
  return 'processed';
end;
$$;

create function billing_private.change_subscription_credit(p_event public.billing_events,p_payment jsonb,p_action text)
returns text language plpgsql security definer set search_path='' as $$
declare s public.subscriptions; r public.billing_payment_receipts; v_until timestamptz;
begin
  select * into s from public.subscriptions where asaas_subscription_id=p_payment->>'subscription';
  if not found then return 'pending'; end if;
  perform 1 from public.profiles where id=s.user_id for update;
  perform 1 from public.subscriptions where id=s.id for update;
  select * into r from public.billing_payment_receipts where payment_id=p_payment->>'id' for update;
  if found and (r.product<>'pro_monthly' or r.pro_user_id is distinct from s.user_id
    or r.subscription_id is distinct from s.id) then raise exception 'RECEIPT_REFERENCE_CONFLICT'; end if;
  if not found then
    insert into public.billing_payment_receipts(payment_id,product,event_id,expires_at,
      subscription_id,pro_user_id,pro_original_expires_at,benefit_applied)
      values(p_payment->>'id','pro_monthly',p_event.id,now(),s.id,s.user_id,now(),false)
      returning * into r;
  end if;
  p_action:=billing_private.reversal_transition(r,p_event,p_action);
  if p_action='skip' then return 'processed'; end if;
  if p_action='pending' then return 'pending'; end if;
  if p_action='restore' then
    v_until:=case when r.benefit_applied then r.pro_original_expires_at else now()+interval '33 days' end;
    update public.billing_payment_receipts set revoked_at=null,expires_at=v_until,
      pro_original_expires_at=v_until,benefit_applied=true where payment_id=r.payment_id;
  else
    update public.billing_payment_receipts set revoked_at=coalesce(revoked_at,now()) where payment_id=r.payment_id;
  end if;
  select max(pro_original_expires_at) into v_until from public.billing_payment_receipts where subscription_id=s.id
    and revoked_at is null and benefit_applied;
  -- Estorno de fatura não altera a recorrência no Asaas nem abre outra assinatura.
  update public.subscriptions set current_period_end=v_until where id=s.id;
  perform billing_private.refresh_pro(s.user_id);
  perform public.notify(s.user_id,'system','Pagamento do Pro atualizado',
    'O benefício desta cobrança foi atualizado. Outros períodos válidos foram preservados.',jsonb_build_object('route','/plans'));
  return 'processed';
end;
$$;
revoke all on function billing_private.apply_subscription_payment(text,jsonb),
  billing_private.change_subscription_credit(public.billing_events,jsonb,text) from public,anon,authenticated,service_role;
