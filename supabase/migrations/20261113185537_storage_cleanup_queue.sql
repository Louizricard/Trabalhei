-- Limpeza de arquivos órfãos no Storage.
-- Rollback: supabase/rollbacks/20261113185537_storage_cleanup_queue_down.sql
--
-- Um arquivo vira órfão quando a pessoa o remove de uma vaga/proposta, quando
-- o registro é apagado ou quando o upload subiu mas o registro não chegou a
-- ser salvo. O app já tenta apagar na hora (AttachmentSaveFlow); o que
-- escapar é encontrado aqui e removido pela Edge Function `storage-cleanup`
-- (pela Storage API: apagar a linha de storage.objects deixaria o arquivo).
--
-- Entregas e revisões de marcos não entram na fila: são histórico do
-- contrato e continuam guardadas mesmo quando substituídas.

create table public.storage_cleanup_queue (
  bucket text not null,
  path text not null,
  reason text not null,
  attempts integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  primary key (bucket, path)
);
-- Só o service_role (Edge Function) lê e altera a fila.
alter table public.storage_cleanup_queue enable row level security;
revoke all on public.storage_cleanup_queue from anon, authenticated;

-- Enfileira os anexos que saíram do registro. TG_ARGV = (coluna, bucket);
-- a coluna pode ser jsonb (lista de anexos) ou texto (uma URL).
create or replace function public.queue_removed_attachments()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_old jsonb := to_jsonb(old) -> tg_argv[0];
  v_new jsonb := case when tg_op = 'UPDATE' then to_jsonb(new) -> tg_argv[0] end;
  v_url text;
  v_path text;
begin
  v_old := case jsonb_typeof(v_old)
    when 'string' then jsonb_build_array(jsonb_build_object('url', v_old #>> '{}'))
    when 'array' then v_old else '[]' end;
  v_new := case jsonb_typeof(v_new)
    when 'string' then jsonb_build_array(jsonb_build_object('url', v_new #>> '{}'))
    when 'array' then v_new else '[]' end;
  for v_url in
    select e->>'url' from jsonb_array_elements(v_old) e
  loop
    continue when v_new @> jsonb_build_array(jsonb_build_object('url', v_url));
    v_path := public.storage_path_from_url(v_url, tg_argv[1]);
    continue when v_path is null;
    insert into public.storage_cleanup_queue (bucket, path, reason)
      values (tg_argv[1], v_path, lower(tg_op) || ':' || tg_table_name)
      on conflict do nothing;
  end loop;
  return null;
end;
$$;
revoke all on function public.queue_removed_attachments() from public, anon, authenticated;

create trigger jobs_queue_removed_attachments
  after update of attachments or delete on public.jobs
  for each row execute function public.queue_removed_attachments('attachments', 'job_attachments');
create trigger jobs_queue_removed_cover
  after update of image_url or delete on public.jobs
  for each row execute function public.queue_removed_attachments('image_url', 'job_covers');

-- Caminhos ainda referenciados por algum registro do app.
create or replace function public.referenced_storage_paths(p_bucket text)
returns setof text language sql stable security definer set search_path = '' as $$
  select public.storage_path_from_url(e->>'url', p_bucket)
    from public.jobs j, jsonb_array_elements(j.attachments) e where p_bucket = 'job_attachments'
  union
  select public.storage_path_from_url(j.image_url, p_bucket)
    from public.jobs j where p_bucket = 'job_covers' and j.image_url is not null
$$;
revoke all on function public.referenced_storage_paths(text) from public, anon, authenticated;

-- Lote para a Edge Function: itens da fila e objetos sem referência mais
-- velhos que p_grace (tempo para um upload em andamento virar registro).
-- Nunca devolve um caminho que voltou a ser referenciado.
create or replace function public.storage_cleanup_batch(
  p_limit integer default 100, p_grace interval default interval '1 day'
) returns table (bucket text, path text)
language sql stable security definer set search_path = '' as $$
  with candidates as (
    select q.bucket, q.path from public.storage_cleanup_queue q where q.attempts < 5
    union
    select o.bucket_id, o.name from storage.objects o
      where o.bucket_id in ('job_attachments', 'job_covers')
        and o.created_at < now() - p_grace
  )
  select c.bucket, c.path from candidates c
  where c.path not in (select r from public.referenced_storage_paths(c.bucket) r where r is not null)
  limit p_limit
$$;

-- Resultado do lote: apagados saem da fila; falhas somam tentativas.
create or replace function public.storage_cleanup_report(p_done jsonb, p_failed jsonb, p_error text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  delete from public.storage_cleanup_queue q
    using jsonb_array_elements(coalesce(p_done, '[]')) d
    where q.bucket = d->>'bucket' and q.path = d->>'path';
  insert into public.storage_cleanup_queue (bucket, path, reason, attempts, last_error)
    select d->>'bucket', d->>'path', 'orphan', 1, p_error
      from jsonb_array_elements(coalesce(p_failed, '[]')) d
    on conflict (bucket, path) do update
      set attempts = public.storage_cleanup_queue.attempts + 1, last_error = excluded.last_error;
end;
$$;

revoke all on function public.storage_cleanup_batch(integer, interval) from public, anon, authenticated;
revoke all on function public.storage_cleanup_report(jsonb, jsonb, text) from public, anon, authenticated;
grant execute on function public.storage_cleanup_batch(integer, interval) to service_role;
grant execute on function public.storage_cleanup_report(jsonb, jsonb, text) to service_role;
