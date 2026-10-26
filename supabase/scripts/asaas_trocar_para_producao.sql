-- Rodar UMA VEZ, logo depois de trocar os secrets do Asaas para produção
-- (ver docs/producao.md, item 5). Os ids de cliente e de assinatura do
-- sandbox não existem na conta de produção: sem esta limpeza, a próxima
-- cobrança tentaria usar um cliente do sandbox e falharia.
begin;

-- Clientes do Asaas (sandbox): serão recriados na primeira cobrança.
delete from public.billing_customers;

-- Assinaturas do sandbox deixam de valer. O plano de quem está como Pro por
-- um pagamento de teste continua até plan_expires_at; para encerrar já,
-- descomente a linha do update em profiles.
update public.subscriptions set status = 'cancelled'
  where status in ('pending', 'active', 'overdue');
-- update public.profiles set plan = 'free', plan_expires_at = null where plan = 'pro';

-- Destaques pendentes do sandbox (não pagos) também saem.
update public.job_featurings set status = 'cancelled' where status = 'pending';

commit;
