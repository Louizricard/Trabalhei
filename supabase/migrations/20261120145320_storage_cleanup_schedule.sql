-- Agenda a Edge Function `storage-cleanup` (arquivos órfãos) uma vez por dia.
-- Rollback: supabase/rollbacks/20261120145320_storage_cleanup_schedule_down.sql
--
-- Nenhuma chave sai do banco: o token que autoriza a chamada é gerado aqui,
-- guardado no Vault e conferido pela função com storage_cleanup_token_ok().
-- O endereço da função fica no segredo `storage_cleanup_url` do Vault, derivado
-- de `notification_dispatch_url` (mesmo projeto), sem URL fixa no código.
-- Sem os segredos, o agendamento não faz nada.

create extension if not exists pg_cron;

do $$
begin
  if not exists (select 1 from vault.secrets where name = 'storage_cleanup_token') then
    perform vault.create_secret(
      replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
      'storage_cleanup_token',
      'Autoriza o Cron a chamar a Edge Function storage-cleanup');
  end if;
  if not exists (select 1 from vault.secrets where name = 'storage_cleanup_url') then
    perform vault.create_secret(
      regexp_replace(decrypted_secret, '/[^/]+$', '/storage-cleanup'),
      'storage_cleanup_url',
      'Endereço da Edge Function storage-cleanup')
    from vault.decrypted_secrets where name = 'notification_dispatch_url';
  end if;
end;
$$;

-- A função recebe o token no cabeçalho e pergunta ao banco se é válido.
create or replace function public.storage_cleanup_token_ok(p_token text)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(p_token, '') <> '' and exists (
    select 1 from vault.decrypted_secrets
    where name = 'storage_cleanup_token' and decrypted_secret = p_token)
$$;
revoke all on function public.storage_cleanup_token_ok(text) from public, anon, authenticated;
grant execute on function public.storage_cleanup_token_ok(text) to service_role;

-- Dispara a limpeza (assíncrono, via pg_net). Devolve o id do pedido.
create or replace function public.run_storage_cleanup()
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  v_url text;
  v_token text;
begin
  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'storage_cleanup_url';
  select decrypted_secret into v_token from vault.decrypted_secrets where name = 'storage_cleanup_token';
  if v_url is null or v_token is null then return null; end if;
  return net.http_post(
    url := v_url,
    body := '{}'::jsonb,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-cleanup-token', v_token),
    timeout_milliseconds := 60000
  );
end;
$$;
revoke all on function public.run_storage_cleanup() from public, anon, authenticated;

-- Todo dia às 03:17 UTC; cada execução apaga até 100 arquivos órfãos.
select cron.schedule('storage-cleanup', '17 3 * * *', 'select public.run_storage_cleanup()');
