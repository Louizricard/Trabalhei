-- Limite de arquivo por plano validado no servidor.
-- Rollback: supabase/rollbacks/20261113120000_plan_upload_limits_down.sql
--
-- O app só aceitava arquivos dentro do limite do plano (free_file_mb/pro_file_mb)
-- no cliente. Agora todo anexo gravado numa vaga, entrega, revisão ou mensagem é
-- conferido aqui: precisa existir no Storage, estar na pasta de quem o anexa e
-- respeitar o limite do plano dessa pessoa. O schema `storage` não é alterado
-- (a Supabase recomenda tratá-lo como somente leitura); o bucket guarda só o teto
-- absoluto, igual ao limite do Pro.

create or replace function public.upload_limit_bytes(p_user uuid)
returns bigint language sql stable security definer set search_path = '' as $$
  select (case when public.is_pro(p_user) then s.pro_file_mb else s.free_file_mb end)::bigint
         * 1024 * 1024
  from public.platform_settings s limit 1
$$;
revoke all on function public.upload_limit_bytes(uuid) from public, anon;
grant execute on function public.upload_limit_bytes(uuid) to authenticated;

-- Caminho do objeto a partir da URL gravada pelo app
-- (".../storage/v1/object/public/<bucket>/<caminho>").
create or replace function public.storage_path_from_url(p_url text, p_bucket text)
returns text language sql immutable set search_path = '' as $$
  select nullif(
    split_part(
      substring(p_url from '/storage/v1/object/(?:public|sign|authenticated)/' || p_bucket || '/(.+)$'),
      '?', 1),
    '')
$$;

-- Confere os anexos novos (ausentes em p_old) da lista p_new.
create or replace function public.assert_attachment_refs(
  p_new jsonb, p_old jsonb, p_bucket text, p_max integer
) returns void language plpgsql stable security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_item jsonb;
  v_path text;
  v_size bigint;
begin
  if v_uid is null then return; end if; -- service_role e rotinas internas
  if jsonb_typeof(coalesce(p_new, '[]')) <> 'array' then raise exception 'ATTACHMENT_INVALID'; end if;
  if jsonb_array_length(coalesce(p_new, '[]')) > p_max then raise exception 'ATTACHMENT_LIMIT'; end if;
  for v_item in select value from jsonb_array_elements(coalesce(p_new, '[]')) loop
    continue when coalesce(p_old, '[]') @> jsonb_build_array(jsonb_build_object('url', v_item->>'url'));
    v_path := public.storage_path_from_url(v_item->>'url', p_bucket);
    if v_path is null then raise exception 'ATTACHMENT_INVALID'; end if;
    if split_part(v_path, '/', 1) <> v_uid::text then raise exception 'ATTACHMENT_NOT_OWNED'; end if;
    select (o.metadata->>'size')::bigint into v_size
      from storage.objects o where o.bucket_id = p_bucket and o.name = v_path;
    if not found then raise exception 'ATTACHMENT_NOT_FOUND'; end if;
    if coalesce(v_size, 0) > public.upload_limit_bytes(v_uid) then
      raise exception 'FILE_TOO_LARGE';
    end if;
  end loop;
end;
$$;
revoke all on function public.assert_attachment_refs(jsonb, jsonb, text, integer) from public, anon, authenticated;

-- Gatilho genérico: TG_ARGV = (coluna jsonb, bucket, máximo de itens).
create or replace function public.enforce_attachment_refs()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_new jsonb := to_jsonb(new) -> tg_argv[0];
  v_old jsonb := case when tg_op = 'UPDATE' then to_jsonb(old) -> tg_argv[0] else '[]'::jsonb end;
begin
  if v_new is distinct from v_old then
    perform public.assert_attachment_refs(v_new, v_old, tg_argv[1], tg_argv[2]::integer);
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_attachment_refs() from public, anon, authenticated;

create trigger jobs_attachment_refs
  before insert or update of attachments on public.jobs
  for each row execute function public.enforce_attachment_refs('attachments', 'job_attachments', '5');
create trigger milestones_attachment_refs
  before update of deliverable_attachments on public.milestones
  for each row execute function public.enforce_attachment_refs('deliverable_attachments', 'chat_attachments', '10');
create trigger milestone_revisions_attachment_refs
  before insert on public.milestone_revisions
  for each row execute function public.enforce_attachment_refs('attachments', 'chat_attachments', '10');

-- Mensagens guardam um único anexo em colunas próprias.
create or replace function public.enforce_message_attachment()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.attachment_url is not null then
    perform public.assert_attachment_refs(
      jsonb_build_array(jsonb_build_object('url', new.attachment_url)), '[]', 'chat_attachments', 1);
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_message_attachment() from public, anon, authenticated;
create trigger messages_attachment_ref
  before insert on public.messages
  for each row execute function public.enforce_message_attachment();

-- Teto absoluto dos buckets = limite padrão do Pro (50 MB). O limite real por
-- plano é o de upload_limit_bytes.
update storage.buckets set file_size_limit = 52428800
  where id in ('job_attachments', 'chat_attachments');
