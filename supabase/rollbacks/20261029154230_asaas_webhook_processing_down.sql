-- Antes de voltar o webhook antigo, suspenda a fila no Asaas e confira a inbox.
-- Conserva eventos/recibos: nunca apagar evidência financeira num rollback.
drop trigger if exists subscriptions_replay_billing on public.subscriptions;
drop trigger if exists featurings_replay_billing on public.job_featurings;
drop function if exists billing_private.replay_linked_events();
drop function if exists public.receive_asaas_billing_event(jsonb);
drop function if exists public.process_asaas_billing_event(text);
drop function if exists billing_private.apply_event(public.billing_events);
