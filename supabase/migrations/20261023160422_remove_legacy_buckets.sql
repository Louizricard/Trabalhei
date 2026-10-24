-- ============================================================================
-- Remove os buckets legados do modelo com custódia/disputas (`deliverables` e
-- `dispute_attachments`). Nenhum código os usa; as entregas vão para
-- `chat_attachments`. A migration aborta se algum deles ainda tiver arquivos.
-- ============================================================================

do $$
begin
  if exists (select 1 from storage.objects
             where bucket_id in ('deliverables', 'dispute_attachments')) then
    raise exception 'Os buckets legados ainda têm arquivos. Esvazie-os antes de remover.';
  end if;
end;
$$;

-- O Storage bloqueia DELETE direto nas suas tabelas; liberado só nesta transação.
set local storage.allow_delete_query = 'true';
delete from storage.buckets where id in ('deliverables', 'dispute_attachments');
