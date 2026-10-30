do $$ begin
  if exists(select 1 from public.billing_payment_receipts where reversal_event_id is not null)
    or exists(select 1 from public.billing_pro_grants where origin='grant') then
    raise exception 'BILLING_REVERSAL_DATA_PRESENT'; end if;
end $$;
drop function billing_private.change_subscription_credit(public.billing_events,jsonb,text);
create or replace function billing_private.apply_subscription_payment(p_event_id text, p_payment jsonb)
returns text language plpgsql security definer set search_path = '' as $$
declare
  s public.subscriptions;
  v_until timestamptz := now() + interval '33 days';
begin
  select * into s from public.subscriptions
    where asaas_subscription_id = p_payment ->> 'subscription' for update;
  if not found then return 'pending'; end if;
  perform 1 from public.profiles where id = s.user_id for update;
  if not found then raise exception 'PROFILE_NOT_FOUND'; end if;
  insert into public.billing_payment_receipts (payment_id, product, event_id, expires_at)
    values (p_payment ->> 'id', 'pro_monthly', p_event_id, v_until)
    on conflict (payment_id) do nothing;
  if not found then return 'processed'; end if;
  update public.subscriptions set status = 'active',
    current_period_end = greatest(current_period_end, v_until) where id = s.id;
  update public.profiles set plan = 'pro',
    plan_expires_at = greatest(plan_expires_at, v_until) where id = s.user_id;
  perform public.notify(s.user_id, 'system', 'Plano Pro ativo 🎉',
    'Mais propostas, modelos, organização de clientes e estatísticas liberados. Obrigado por apoiar o Trabalhei!',
    jsonb_build_object('route', '/plans'));
  return 'processed';
end;
$$;

