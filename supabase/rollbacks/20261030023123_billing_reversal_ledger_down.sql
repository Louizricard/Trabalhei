do $$ begin
  if exists(select 1 from public.billing_payment_receipts where reversal_event_id is not null)
    or exists(select 1 from public.billing_pro_grants where origin='grant') then
    raise exception 'BILLING_REVERSAL_DATA_PRESENT'; end if;
end $$;
create or replace function public.grant_pro(p_user uuid, p_days integer, p_reason text)
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
drop function billing_private.refresh_pro(uuid);
drop table public.billing_pro_grants;
alter table public.billing_payment_receipts drop column subscription_id,drop column pro_user_id,drop column pro_original_expires_at,drop column benefit_applied,drop column reversal_state,drop column reversal_at,drop column reversal_event_id;

