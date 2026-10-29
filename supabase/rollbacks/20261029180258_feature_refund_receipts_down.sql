do $$ begin
  if exists(select 1 from public.billing_payment_receipts where revoked_at is not null) then
    raise exception 'FEATURE_REFUND_DATA_PRESENT';
  end if;
end $$;
drop index public.billing_receipts_revocation_event_idx;
alter table public.billing_payment_receipts
  drop constraint feature_receipt_interval,
  drop column feature_starts_at,drop column feature_original_expires_at,
  drop column revoked_at,drop column revocation_event_id,drop column revoked_seconds;
