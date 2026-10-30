do $$ begin
  if exists(select 1 from public.billing_payment_receipts where reversal_event_id is not null)
    or exists(select 1 from public.billing_pro_grants where origin='grant') then
    raise exception 'BILLING_REVERSAL_DATA_PRESENT'; end if;
end $$;
drop function billing_private.route_payment(public.billing_events,text);
drop function billing_private.full_refund(jsonb);
drop function billing_private.reversal_transition(public.billing_payment_receipts,public.billing_events,text);

