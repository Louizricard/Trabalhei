-- Só reverte o schema se o processador novo ainda não recebeu eventos.
-- Depois de tráfego real, use apenas o rollback operacional da migration seguinte,
-- preservando a inbox/recibos para recuperação e auditoria.
do $$ begin
  if exists (select 1 from public.billing_events where processing_status <> 'legacy') then
    raise exception 'BILLING_DATA_PRESENT: preserve inbox and receipts; use operational rollback';
  end if;
end $$;

drop function billing_private.apply_feature_payment(text, jsonb);
drop function billing_private.apply_subscription_payment(text, jsonb);
drop function billing_private.apply_subscription_status(jsonb);
drop schema billing_private;
drop table public.billing_payment_receipts;
drop index public.billing_events_pending_payment_idx;
drop index public.billing_events_pending_subscription_idx;
alter table public.billing_events
  drop column received_at,
  drop column processing_status,
  drop column attempts,
  drop column last_error_code,
  alter column processed_at set not null;
