-- Entrega das notificações por e-mail e push (Web Push). Cada notificação
-- criada chama a Edge Function dispatch-notification pelo pg_net; a função
-- envia o e-mail (Resend) e o push conforme as preferências da pessoa.
-- Chaves e endereços ficam no Vault (nunca no código):
--   notification_dispatch_url, resend_api_key, vapid_public_key,
--   vapid_private_key, app_url
create extension if not exists pg_net with schema extensions;

-- Preferências de entrega. Sem linha, vale o padrão (tudo ligado).
create table public.notification_settings (
  user_id uuid primary key default auth.uid() references public.profiles (id) on delete cascade,
  email_enabled boolean not null default true,
  push_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.notification_settings enable row level security;
create policy notification_settings_own on public.notification_settings
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
revoke all on public.notification_settings from anon;

-- Navegadores inscritos para receber push.
create table public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  endpoint text not null unique check (endpoint ~ '^https://' and char_length(endpoint) <= 1000),
  p256dh text not null check (char_length(p256dh) <= 200),
  auth text not null check (char_length(auth) <= 100),
  user_agent text check (user_agent is null or char_length(user_agent) <= 300),
  created_at timestamptz not null default now()
);
create index push_subscriptions_user_idx on public.push_subscriptions (user_id);
alter table public.push_subscriptions enable row level security;
create policy push_subscriptions_own on public.push_subscriptions
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
revoke all on public.push_subscriptions from anon;

-- Marca de entrega: a função só envia uma vez por notificação.
alter table public.notifications add column delivered_at timestamptz;

create function public.dispatch_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
begin
  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'notification_dispatch_url';
  if v_url is null then return null; end if;
  perform net.http_post(
    url := v_url,
    body := jsonb_build_object('id', new.id),
    headers := '{"Content-Type": "application/json"}'::jsonb,
    timeout_milliseconds := 10000
  );
  return null;
end;
$$;
revoke all on function public.dispatch_notification() from public, anon, authenticated;

create trigger notifications_dispatch
  after insert on public.notifications
  for each row execute function public.dispatch_notification();

-- Chaves para a Edge Function (só o service_role executa).
create function public.notification_secrets()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_object_agg(name, decrypted_secret), '{}'::jsonb)
  from vault.decrypted_secrets
  where name in ('resend_api_key', 'vapid_public_key', 'vapid_private_key', 'app_url')
$$;
revoke all on function public.notification_secrets() from public, anon, authenticated;
grant execute on function public.notification_secrets() to service_role;

-- Chave pública do Web Push, usada pelo navegador para se inscrever.
create function public.push_public_key()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select decrypted_secret from vault.decrypted_secrets where name = 'vapid_public_key'
$$;
revoke all on function public.push_public_key() from public, anon;
grant execute on function public.push_public_key() to authenticated;
