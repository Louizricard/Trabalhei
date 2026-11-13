-- Desfaz 20261113120200_storage_cleanup_queue. Recusa rodar com itens na
-- fila: seriam arquivos órfãos esquecidos (custo de Storage sem dono).
do $$
begin
  if exists (select 1 from public.storage_cleanup_queue) then
    raise exception 'CLEANUP_QUEUE_NOT_EMPTY';
  end if;
end $$;
drop trigger if exists jobs_queue_removed_attachments on public.jobs;
drop trigger if exists jobs_queue_removed_cover on public.jobs;
drop function if exists public.storage_cleanup_report(jsonb, jsonb, text);
drop function if exists public.storage_cleanup_batch(integer, interval);
drop function if exists public.referenced_storage_paths(text);
drop function if exists public.queue_removed_attachments();
drop table if exists public.storage_cleanup_queue;
