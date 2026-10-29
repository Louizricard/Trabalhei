do $$ begin
  if exists(select 1 from public.billing_payment_receipts where revoked_at is not null) then
    raise exception 'FEATURE_REFUND_DATA_PRESENT';
  end if;
end $$;
create or replace function billing_private.apply_event(p_event public.billing_events)
returns text language plpgsql security definer set search_path = '' as $$
begin
  if p_event.event in ('PAYMENT_CONFIRMED', 'PAYMENT_RECEIVED') then
    if coalesce(p_event.payload #>> '{payment,externalReference}', '') like 'feature:%' then
      return billing_private.apply_feature_payment(p_event.id, p_event.payload -> 'payment');
    elsif nullif(p_event.payload #>> '{payment,subscription}', '') is not null then
      return billing_private.apply_subscription_payment(p_event.id, p_event.payload -> 'payment');
    end if;
  elsif p_event.event in ('PAYMENT_OVERDUE', 'PAYMENT_REFUNDED', 'PAYMENT_CHARGEBACK_REQUESTED',
                         'SUBSCRIPTION_INACTIVATED', 'SUBSCRIPTION_DELETED') then
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
  if p_payload ->> 'event' in ('PAYMENT_CONFIRMED', 'PAYMENT_RECEIVED')
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

