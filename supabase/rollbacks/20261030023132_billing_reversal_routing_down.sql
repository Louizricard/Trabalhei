do $$ begin
  if exists(select 1 from public.billing_payment_receipts where reversal_event_id is not null)
    or exists(select 1 from public.billing_pro_grants where origin='grant') then
    raise exception 'BILLING_REVERSAL_DATA_PRESENT'; end if;
end $$;
create or replace function billing_private.apply_event(p_event public.billing_events)
returns text language plpgsql security definer set search_path='' as $$
begin
  if p_event.event='PAYMENT_REFUNDED' and (
    nullif(p_event.payload#>>'{payment,subscription}','') is null
    or coalesce(p_event.payload#>>'{payment,externalReference}','') like 'feature:%'
    or exists(select 1 from public.job_featurings where asaas_payment_id=p_event.payload#>>'{payment,id}')
  ) then
    -- Sem referência externa, o ID local continua suficiente para correlacionar.
    -- Um vínculo ainda ausente fica pendente, em vez de consumir o estorno.
    if coalesce(p_event.payload#>>'{payment,externalReference}','') not like 'feature:%'
      and coalesce(p_event.payload#>>'{payment,externalReference}','')<>''
      and not exists(select 1 from public.job_featurings where asaas_payment_id=p_event.payload#>>'{payment,id}')
      then return 'ignored'; end if;
    return billing_private.apply_feature_refund(p_event.id,p_event.payload->'payment');
  elsif p_event.event in ('PAYMENT_CONFIRMED','PAYMENT_RECEIVED') then
    if coalesce(p_event.payload#>>'{payment,externalReference}','') like 'feature:%' then
      return billing_private.apply_feature_payment(p_event.id,p_event.payload->'payment');
    elsif nullif(p_event.payload#>>'{payment,subscription}','') is not null then
      return billing_private.apply_subscription_payment(p_event.id,p_event.payload->'payment');
    end if;
  elsif p_event.event in ('PAYMENT_OVERDUE','PAYMENT_REFUNDED','PAYMENT_CHARGEBACK_REQUESTED',
    'SUBSCRIPTION_INACTIVATED','SUBSCRIPTION_DELETED') then
    return billing_private.apply_subscription_status(p_event.payload);
  end if;
  return 'ignored';
end;
$$;
create or replace function public.receive_asaas_billing_event(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_id text := p_payload ->> 'id';
  e public.billing_events;
begin
  if jsonb_typeof(p_payload) <> 'object' or coalesce(length(trim(v_id)), 0) not between 1 and 200
    or jsonb_typeof(p_payload -> 'id') <> 'string'
    or coalesce(length(trim(p_payload ->> 'event')), 0) not between 1 and 100
    or jsonb_typeof(p_payload -> 'event') <> 'string' then
    raise exception 'INVALID_EVENT' using errcode = '22023';
  end if;
  if p_payload ->> 'event' in ('PAYMENT_CONFIRMED', 'PAYMENT_RECEIVED', 'PAYMENT_REFUNDED')
    and (jsonb_typeof(p_payload #> '{payment,id}') is distinct from 'string'
         or coalesce(length(trim(p_payload #>> '{payment,id}')), 0) = 0) then
    raise exception 'INVALID_PAYMENT' using errcode = '22023';
  end if;
  insert into public.billing_events (id, event, payload, processed_at, processing_status)
    values (v_id, p_payload ->> 'event', p_payload, null, 'pending')
    on conflict (id) do nothing;
  select * into strict e from public.billing_events where id = v_id;
  -- Nunca sobrescreve o corpo original ao receber novamente o mesmo id.
  if e.event <> p_payload ->> 'event'
    or (e.payload #>> '{payment,id}') is distinct from (p_payload #>> '{payment,id}')
    or (e.payload #>> '{subscription,id}') is distinct from (p_payload #>> '{subscription,id}') then
    raise exception 'EVENT_ID_CONFLICT' using errcode = '22023';
  end if;
  return public.process_asaas_billing_event(v_id);
end;
$$;
create or replace function public.process_asaas_billing_event(p_event_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  e public.billing_events;
  v_status text;
begin
  select * into strict e from public.billing_events where id = p_event_id for update;
  if e.processing_status in ('processed', 'ignored', 'legacy') then
    return jsonb_build_object('status', e.processing_status, 'duplicate', true);
  end if;
  update public.billing_events set attempts = attempts + 1, last_error_code = null where id = e.id;
  -- Subtransação: qualquer falha desfaz TODO o efeito, mas conserva a inbox.
  begin
    v_status := billing_private.apply_event(e);
    update public.billing_events set processing_status = v_status,
      processed_at = case when v_status in ('processed', 'ignored') then now() else null end,
      last_error_code = case when v_status = 'pending' then 'MISSING_BILLING_REFERENCE' end
      where id = e.id;
  exception when others then
    update public.billing_events set processing_status = 'failed', processed_at = null,
      last_error_code = sqlstate where id = e.id;
    return jsonb_build_object('status', 'failed', 'error_code', sqlstate);
  end;
  return jsonb_build_object('status', v_status, 'duplicate', false);
end;
$$;
create or replace function billing_private.apply_subscription_status(p_payload jsonb)
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

