create function billing_private.reversal_transition(r public.billing_payment_receipts,e public.billing_events,p_action text)
returns text language plpgsql security definer set search_path='' as $$
declare v_clock timestamptz:=nullif(e.payload->>'dateCreated','')::timestamptz;
  v_state text; v_won boolean;
begin
  if r.reversal_state='refunded' then return 'skip'; end if;
  if p_action<>'refund' and v_clock<r.reversal_at then return 'skip'; end if;
  if p_action='restore' then
    v_won:=coalesce(e.payload#>>'{payment,chargeback,status}'='REVERSED'
      or (e.payload#>>'{payment,chargeback,status}'='DONE'
        and e.payload#>>'{payment,status}' in('CONFIRMED','RECEIVED')),false);
    if not v_won and not coalesce(r.reversal_state='awaiting' and v_clock>r.reversal_at,false) then
      return case when r.reversal_state='awaiting' then 'pending' else 'skip' end;
    end if;
    if r.reversal_state='restored' then return 'skip'; end if;
    v_state:='restored';
  elsif p_action='refund' then v_state:='refunded';
  else
    if r.reversal_state='restored' and (v_clock is null or r.reversal_at is null or v_clock<=r.reversal_at)
      or r.reversal_state='awaiting' and p_action='hold'
        and (v_clock is null or r.reversal_at is null or v_clock<=r.reversal_at)
      then return 'skip'; end if;
    v_state:=case when p_action='awaiting' then 'awaiting' else 'held' end;
  end if;
  update public.billing_payment_receipts set reversal_state=v_state,reversal_at=coalesce(v_clock,reversal_at),
    reversal_event_id=e.id where payment_id=r.payment_id;
  if p_action='restore' and r.revoked_at is null and r.benefit_applied then return 'skip'; end if;
  if p_action in('hold','awaiting') and r.revoked_at is not null then return 'skip'; end if;
  return p_action;
end;
$$;

create function billing_private.route_payment(e public.billing_events,p_action text)
returns text language plpgsql security definer set search_path='' as $$
declare r public.billing_payment_receipts; p jsonb:=e.payload->'payment'; v_pro boolean;
begin
  select * into r from public.billing_payment_receipts where payment_id=p->>'id';
  if r.payment_id is null and nullif(p->>'subscription','') is null
    and coalesce(p->>'externalReference','') not like 'feature:%'
    and not exists(select 1 from public.job_featurings where asaas_payment_id=p->>'id')
    and (p_action='confirm' or coalesce(p->>'externalReference','')<>'') then return 'ignored'; end if;
  if exists(select 1 from public.job_featurings where asaas_payment_id=p->>'id')
    or coalesce(p->>'externalReference','') like 'feature:%' or r.product='job_feature' then v_pro:=false;
  else v_pro:=r.product='pro_monthly' or nullif(p->>'subscription','') is not null; end if;
  if r.product='pro_monthly' and r.pro_user_id is null and r.subscription_id is null then return 'processed'; end if;
  if v_pro and nullif(p->>'subscription','') is null then
    p:=p||jsonb_build_object('subscription',(select asaas_subscription_id from public.subscriptions where id=r.subscription_id));
  end if;
  if p_action='confirm' and r.reversal_state in('held','awaiting') then p_action:='restore'; end if;
  if p_action='confirm' then
    if v_pro then return billing_private.apply_subscription_payment(e.id,p); end if;
    return billing_private.apply_feature_payment(e.id,p);
  end if;
  if v_pro then return billing_private.change_subscription_credit(e,p,p_action); end if;
  return billing_private.change_feature_credit(e,p,p_action);
end;
$$;

create function billing_private.full_refund(p_payment jsonb)
returns boolean language plpgsql immutable set search_path='' as $$
declare v_done numeric;
begin
  if p_payment->>'status' in('PARTIALLY_REFUNDED','REFUND_REQUESTED','REFUND_IN_PROGRESS') then return false; end if;
  if jsonb_typeof(p_payment->'refunds')='array' and (p_payment->>'value')::numeric>0 then
    select coalesce(sum((x->>'value')::numeric),0) into v_done from jsonb_array_elements(p_payment->'refunds') x
      where x->>'status'='DONE';
    return v_done>=(p_payment->>'value')::numeric;
  end if;
  return true;
end;
$$;

create or replace function billing_private.apply_event(p_event public.billing_events)
returns text language plpgsql security definer set search_path='' as $$
declare v_event text:=p_event.event; v_cb text:=p_event.payload#>>'{payment,chargeback,status}';
begin
  if v_cb is not null and v_cb not in('REQUESTED','IN_DISPUTE','DISPUTE_LOST','REVERSED','DONE')
    then return 'pending'; end if;
  if v_event='PAYMENT_REFUNDED' then
    if not billing_private.full_refund(p_event.payload->'payment') then return 'ignored'; end if;
    return billing_private.route_payment(p_event,'refund');
  end if;
  if v_event in('PAYMENT_CHARGEBACK_REQUESTED','PAYMENT_CHARGEBACK_DISPUTE')
    or v_event in('PAYMENT_CONFIRMED','PAYMENT_RECEIVED','PAYMENT_UPDATED')
      and (v_cb in('REQUESTED','IN_DISPUTE','DISPUTE_LOST')
        or p_event.payload#>>'{payment,status}' in('CHARGEBACK_REQUESTED','CHARGEBACK_DISPUTE')) then
    return billing_private.route_payment(p_event,'hold');
  end if;
  if v_event='PAYMENT_AWAITING_CHARGEBACK_REVERSAL'
    or v_event in('PAYMENT_CONFIRMED','PAYMENT_RECEIVED','PAYMENT_UPDATED')
      and p_event.payload#>>'{payment,status}'='AWAITING_CHARGEBACK_REVERSAL'
    then return billing_private.route_payment(p_event,'awaiting'); end if;
  if v_event in('PAYMENT_CONFIRMED','PAYMENT_RECEIVED') then
    if p_event.payload#>>'{payment,status}'='REFUNDED' then return billing_private.route_payment(p_event,'refund'); end if;
    return billing_private.route_payment(p_event,case when v_cb='REVERSED'
      or v_cb='DONE' and p_event.payload#>>'{payment,status}' in('CONFIRMED','RECEIVED') then 'restore' else 'confirm' end);
  end if;
  if v_event in('PAYMENT_OVERDUE','SUBSCRIPTION_INACTIVATED','SUBSCRIPTION_DELETED') then
    return billing_private.apply_subscription_status(p_event.payload);
  end if;
  return 'ignored';
end;
$$;
revoke all on function billing_private.reversal_transition(public.billing_payment_receipts,public.billing_events,text),
  billing_private.route_payment(public.billing_events,text),billing_private.full_refund(jsonb),billing_private.apply_event(public.billing_events)
  from public,anon,authenticated,service_role;
