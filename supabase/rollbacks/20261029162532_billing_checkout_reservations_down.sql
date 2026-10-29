-- Não apaga o diário: remover reservas permitiria repetir POSTs inconclusivos.
-- Pare os dois endpoints antes de voltar o código; preserve as tabelas para conciliação.
drop function public.record_billing_step(uuid,text);
drop function public.reject_billing_step(uuid,uuid,uuid);
drop function public.reserve_billing_step(uuid,uuid,text);
drop function public.release_billing_checkout(uuid,uuid);
drop function billing_private.lock_checkout(uuid,uuid);
drop function public.claim_billing_checkout(uuid,text,uuid,text,text,uuid);
drop index public.job_featurings_one_pending_per_job;
drop index public.subscriptions_one_open_per_user;
-- As tabelas e índices do diário ficam intencionalmente preservados.
