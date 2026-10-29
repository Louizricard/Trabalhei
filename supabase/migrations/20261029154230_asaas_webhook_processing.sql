create function billing_private.apply_event(p_event public.billing_events)
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

-- A trava do evento serializa reenvios. As travas do pagamento e do recurso
-- serializam eventos diferentes do mesmo pagamento e compras da mesma vaga.
create function public.process_asaas_billing_event(p_event_id text)
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

create function public.receive_asaas_billing_event(p_payload jsonb)
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

-- Se o webhook chegou antes do INSERT local do checkout, o próprio vínculo
-- retoma os eventos pendentes. Falhas continuam registradas para reenvio/reparo.
create function billing_private.replay_linked_events()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  e record;
  v_reference text;
begin
  if tg_table_name = 'subscriptions' then
    v_reference := new.asaas_subscription_id;
    for e in select id from public.billing_events
      where processing_status in ('pending', 'failed')
        and coalesce(payload #>> '{payment,subscription}', payload #>> '{subscription,id}') = v_reference
      order by received_at, id
    loop
      perform public.process_asaas_billing_event(e.id);
    end loop;
  else
    v_reference := new.asaas_payment_id;
    for e in select id from public.billing_events
      where processing_status in ('pending', 'failed') and payload #>> '{payment,id}' = v_reference
      order by received_at, id
    loop
      perform public.process_asaas_billing_event(e.id);
    end loop;
  end if;
  return null;
end;
$$;

create trigger subscriptions_replay_billing after insert on public.subscriptions
  for each row execute function billing_private.replay_linked_events();
create trigger featurings_replay_billing after insert on public.job_featurings
  for each row execute function billing_private.replay_linked_events();

revoke all on all functions in schema billing_private from public, anon, authenticated;
revoke all on function public.receive_asaas_billing_event(jsonb), public.process_asaas_billing_event(text)
  from public, anon, authenticated;
grant execute on function public.receive_asaas_billing_event(jsonb), public.process_asaas_billing_event(text)
  to service_role;
