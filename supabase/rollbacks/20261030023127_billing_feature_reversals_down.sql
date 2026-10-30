do $$ begin
  if exists(select 1 from public.billing_payment_receipts where reversal_event_id is not null)
    or exists(select 1 from public.billing_pro_grants where origin='grant') then
    raise exception 'BILLING_REVERSAL_DATA_PRESENT'; end if;
end $$;
drop function billing_private.change_feature_credit(public.billing_events,jsonb,text);
drop function billing_private.restore_feature_credit(public.job_featurings,public.billing_payment_receipts,text);

