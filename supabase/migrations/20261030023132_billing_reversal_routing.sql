-- Todos os eventos financeiros exigem payment.id também na RPC (defesa em profundidade).
create or replace function public.receive_asaas_billing_event(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id text:=p_payload->>'id'; e public.billing_events;
begin
  if jsonb_typeof(p_payload)<>'object' or coalesce(length(trim(v_id)),0) not between 1 and 200
    or jsonb_typeof(p_payload->'id')<>'string'
    or coalesce(length(trim(p_payload->>'event')),0) not between 1 and 100
    or jsonb_typeof(p_payload->'event')<>'string' then raise exception 'INVALID_EVENT' using errcode='22023'; end if;
  if p_payload->>'event' in('PAYMENT_CONFIRMED','PAYMENT_RECEIVED','PAYMENT_REFUNDED',
    'PAYMENT_CHARGEBACK_REQUESTED','PAYMENT_CHARGEBACK_DISPUTE','PAYMENT_AWAITING_CHARGEBACK_REVERSAL','PAYMENT_UPDATED')
    and (jsonb_typeof(p_payload#>'{payment,id}') is distinct from 'string'
      or coalesce(length(trim(p_payload#>>'{payment,id}')),0)=0) then raise exception 'INVALID_PAYMENT' using errcode='22023'; end if;
  insert into public.billing_events(id,event,payload,processed_at,processing_status)
    values(v_id,p_payload->>'event',p_payload,null,'pending') on conflict(id) do nothing;
  select * into strict e from public.billing_events where id=v_id;
  if e.event<>p_payload->>'event' or (e.payload#>>'{payment,id}') is distinct from(p_payload#>>'{payment,id}')
    or (e.payload#>>'{subscription,id}') is distinct from(p_payload#>>'{subscription,id}')
    then raise exception 'EVENT_ID_CONFLICT' using errcode='22023'; end if;
  return public.process_asaas_billing_event(v_id);
end;
$$;

create or replace function public.process_asaas_billing_event(p_event_id text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare e public.billing_events; v_status text; pending record;
begin
  select * into strict e from public.billing_events where id=p_event_id for update;
  if e.processing_status in('processed','ignored','legacy') then
    return jsonb_build_object('status',e.processing_status,'duplicate',true); end if;
  update public.billing_events set attempts=attempts+1,last_error_code=null where id=e.id;
  begin
    v_status:=billing_private.apply_event(e);
    if e.event in('PAYMENT_CONFIRMED','PAYMENT_RECEIVED') and v_status='processed' then
      -- Um estorno sem subscription pode anteceder o vínculo. O novo recibo
      -- permite correlacionar seu ID; ele não é consumido como destaque inexistente.
      for pending in select id from public.billing_events where id<>e.id
        and payload#>>'{payment,id}'=e.payload#>>'{payment,id}' and processing_status in('pending','failed')
        and event in('PAYMENT_REFUNDED','PAYMENT_CHARGEBACK_REQUESTED','PAYMENT_CHARGEBACK_DISPUTE','PAYMENT_AWAITING_CHARGEBACK_REVERSAL')
        order by received_at,id
      loop perform public.process_asaas_billing_event(pending.id); end loop;
    end if;
    update public.billing_events set processing_status=v_status,
      processed_at=case when v_status in('processed','ignored') then now() end,
      last_error_code=case when v_status='pending' then 'MISSING_BILLING_REFERENCE' end where id=e.id;
  exception when others then
    update public.billing_events set processing_status='failed',processed_at=null,last_error_code=sqlstate where id=e.id;
    return jsonb_build_object('status','failed','error_code',sqlstate);
  end;
  return jsonb_build_object('status',v_status,'duplicate',false);
end;
$$;

-- Só cancelamento real da recorrência altera status; nenhuma fatura apaga o plano inteiro.
create or replace function billing_private.apply_subscription_status(p_payload jsonb)
returns text language plpgsql security definer set search_path='' as $$
declare s public.subscriptions; v_event text:=p_payload->>'event';
begin
  if v_event not in('PAYMENT_OVERDUE','SUBSCRIPTION_INACTIVATED','SUBSCRIPTION_DELETED') then return 'ignored'; end if;
  select * into s from public.subscriptions where asaas_subscription_id=coalesce(
    p_payload#>>'{payment,subscription}',p_payload#>>'{subscription,id}');
  if not found then return case when p_payload#>>'{payment,subscription}' is null
    and p_payload#>>'{subscription,id}' is null then 'ignored' else 'pending' end; end if;
  perform 1 from public.profiles where id=s.user_id for update;
  update public.subscriptions set status=case when v_event='PAYMENT_OVERDUE' and status<>'cancelled'
    then 'overdue' else 'cancelled' end where id=s.id;
  return 'processed';
end;
$$;
revoke all on function billing_private.apply_subscription_status(jsonb) from public,anon,authenticated,service_role;
revoke all on function public.receive_asaas_billing_event(jsonb),public.process_asaas_billing_event(text) from public,anon,authenticated;
grant execute on function public.receive_asaas_billing_event(jsonb),public.process_asaas_billing_event(text) to service_role;
