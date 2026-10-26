-- Desfaz 20261026110910_notification_delivery. Os segredos no Vault
-- (notification_dispatch_url, resend_api_key, vapid_*, app_url) ficam; apague-os
-- à parte se não forem mais usados.
drop function if exists public.push_public_key();
drop function if exists public.notification_secrets();
drop trigger if exists notifications_dispatch on public.notifications;
drop function if exists public.dispatch_notification();
alter table public.notifications drop column if exists delivered_at;
drop table if exists public.push_subscriptions;
drop table if exists public.notification_settings;
