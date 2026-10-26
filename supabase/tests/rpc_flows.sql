-- Testes das regras de negócio do banco (RLS + funções do servidor).
--
-- Como rodar: cole no SQL Editor do Supabase (ou `psql`) de um projeto de DESENVOLVIMENTO.
-- ATENÇÃO: rode UM BLOCO POR VEZ (a função auxiliar `pg_temp.act` + um `do $$ ... $$`),
-- pois cada bloco termina com um erro proposital que aborta o script.
-- Cada bloco cria usuários fictícios (@example.invalid), exercita os fluxos como
-- `authenticated` (com JWT simulado) e termina com `raise exception`, o que DESFAZ tudo:
-- nada fica gravado. O relatório aparece na mensagem de erro. Procure por "FALHA".
--
-- Cobertura: publicar vaga, propostas (cota do plano), contraproposta, contrato e marcos,
-- entrega/revisão/aprovação, avaliações, chat/notificações e tentativas de escalada de privilégio.

create or replace function pg_temp.act(u uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', u::text, true);
  execute 'set local role authenticated';
end $$;

-- ============================================================================
-- Bloco 1: fluxo principal + segurança
-- ============================================================================
do $$
declare
  c uuid := gen_random_uuid(); f1 uuid := gen_random_uuid(); f2 uuid := gen_random_uuid();
  log text := ''; job1 uuid; p1 uuid; p2 uuid; r jsonb; contract uuid; conv uuid; ms uuid;
  n int; s text; j uuid; i int;
begin
  insert into auth.users (id, email, raw_user_meta_data, aud, role) values
    (c,  'test-client@example.invalid', '{"full_name":"Cliente Teste","role":"client"}', 'authenticated','authenticated'),
    (f1, 'test-f1@example.invalid', '{"full_name":"Free Um","role":"freelancer"}', 'authenticated','authenticated'),
    (f2, 'test-f2@example.invalid', '{"full_name":"Free Dois","role":"freelancer"}', 'authenticated','authenticated');
  select count(*) into n from public.profiles where id in (c,f1,f2);
  log := log || format('[1] perfis criados pelo trigger: %s/3', n) || E'\n';

  perform pg_temp.act(c);
  insert into public.jobs (client_id,title,category,description,budget_min,budget_max,deadline_days)
    values (c,'Vaga de teste 1','Mobile','Descricao longa o bastante',1000,3000,30) returning id into job1;
  reset role; perform pg_temp.act(f1);
  begin
    insert into public.jobs (client_id,title,category,description,budget_min,budget_max) values (f1,'Vaga indevida','Mobile','Descricao longa o bastante',1,2);
    log := log || '[2b] FALHA: freelancer publicou vaga' || E'\n';
  exception when others then log := log || '[2b] freelancer bloqueado de publicar vaga: OK' || E'\n'; end;

  select (public.submit_proposal(job1, 2000, 10, 'carta f1', '[]'::jsonb)).id into p1;
  perform public.submit_proposal(job1, 2100, 12, 'carta f1 editada', '[]'::jsonb);
  select bid_amount into s from public.proposals where id = p1;
  log := log || format('[3b] edição mantém 1 proposta e atualiza valor: %s (esperado 2100.00)', s) || E'\n';
  reset role; perform pg_temp.act(f2);
  select (public.submit_proposal(job1, 1800, 8, 'carta f2', '[]'::jsonb)).id into p2;
  reset role; perform pg_temp.act(c);
  begin perform public.submit_proposal(job1, 1500, 5, 'x', '[]'::jsonb); log := log || '[3d] FALHA: cliente propôs' || E'\n';
  exception when others then log := log || '[3d] cliente não pode propor: OK' || E'\n'; end;
  select count(*) into n from public.proposals;
  log := log || format('[4] cliente enxerga %s propostas (esperado 2)', n) || E'\n';
  reset role; perform pg_temp.act(f2);
  select count(*) into n from public.proposals;
  log := log || format('[4b] F2 enxerga %s proposta(s) (esperado 1)', n) || E'\n';

  reset role; perform pg_temp.act(c);
  perform public.make_counter_offer(p1, 1900, 9, 'fecha por 1900?');
  reset role; perform pg_temp.act(f1);
  r := public.accept_counter_offer(p1);
  contract := (r->>'contract_id')::uuid; conv := (r->>'conversation_id')::uuid;
  reset role;
  select total_amount into s from public.contracts where id = contract;
  log := log || format('[5c] valor do contrato = %s (esperado 1900.00)', s) || E'\n';
  select status into s from public.proposals where id = p2;
  log := log || format('[5e] proposta concorrente: %s (esperado rejected)', s) || E'\n';
  select status into s from public.jobs where id = job1;
  log := log || format('[5f] vaga: %s (esperado in_progress)', s) || E'\n';
  select id into ms from public.milestones where contract_id = contract limit 1;

  perform pg_temp.act(f2);
  begin perform public.submit_deliverable(ms,'invasor','[]'::jsonb); log := log || '[6] FALHA: F2 entregou em contrato alheio' || E'\n';
  exception when others then log := log || '[6] F2 bloqueado em contrato alheio: OK' || E'\n'; end;
  select count(*) into n from public.contracts; log := log || format('[6b] F2 enxerga %s contratos (esperado 0)', n) || E'\n';

  reset role; perform pg_temp.act(f1);
  perform public.submit_deliverable(ms,'primeira entrega','[]'::jsonb);
  reset role; perform pg_temp.act(c);
  begin perform public.request_revision(ms,'  ','[]'::jsonb); log := log || '[7b] FALHA: revisão sem comentário' || E'\n';
  exception when others then log := log || '[7b] revisão sem comentário bloqueada: OK' || E'\n'; end;
  perform public.request_revision(ms,'ajustar o logo','[]'::jsonb);
  reset role; perform pg_temp.act(f1);
  perform public.submit_deliverable(ms,'segunda entrega','[]'::jsonb);
  reset role; perform pg_temp.act(c);
  begin insert into public.reviews (contract_id,reviewer_id,target_id,rating,comment) values (contract,c,f1,5,'cedo demais');
    log := log || '[8a] FALHA: avaliou contrato não concluído' || E'\n';
  exception when others then log := log || '[8a] avaliação antes de concluir bloqueada: OK' || E'\n'; end;
  r := public.approve_milestone(ms);
  reset role;
  select status into s from public.contracts where id = contract; log := log || format('[8b] contrato: %s (esperado completed)', s) || E'\n';
  select completed_jobs_count into n from public.profiles where id = f1; log := log || format('[8d] completed_jobs_count F1: %s (esperado 1)', n) || E'\n';

  perform pg_temp.act(c);
  insert into public.reviews (contract_id,reviewer_id,target_id,rating,comment) values (contract,c,f1,4,'bom');
  begin insert into public.reviews (contract_id,reviewer_id,target_id,rating) values (contract,c,f1,5);
    log := log || '[9b] FALHA: avaliação duplicada' || E'\n';
  exception when others then log := log || '[9b] avaliação duplicada bloqueada: OK' || E'\n'; end;
  begin insert into public.reviews (contract_id,reviewer_id,target_id,rating) values (contract,c,f2,5);
    log := log || '[9c] FALHA: avaliou quem não participou' || E'\n';
  exception when others then log := log || '[9c] avaliar terceiro bloqueado: OK' || E'\n'; end;
  reset role;
  select rating::text || ' / ' || reviews_count into s from public.profiles where id = f1;
  log := log || format('[9d] nota/total do F1: %s (esperado 4.00 / 1)', s) || E'\n';

  perform pg_temp.act(c);
  insert into public.messages (conversation_id, sender_id, content) values (conv, c, 'oi, tudo bem?');
  reset role;
  select count(*) into n from public.notifications where user_id = f1 and type='new_message';
  log := log || format('[10b] notificação new_message p/ F1: %s (esperado 1)', n) || E'\n';
  perform pg_temp.act(f1);
  perform public.mark_conversation_read(conv);
  select count(*) into n from public.messages where conversation_id = conv and sender_id = c and not is_read;
  log := log || format('[10c] não lidas após marcar lidas: %s (esperado 0)', n) || E'\n';
  begin insert into public.messages (conversation_id, sender_id, content, message_type) values (conv, f1, 'forjada', 'system_event');
    log := log || '[10d] FALHA: usuário criou mensagem de sistema' || E'\n';
  exception when others then log := log || '[10d] mensagem de sistema forjada bloqueada: OK' || E'\n'; end;
  reset role; perform pg_temp.act(f2);
  select count(*) into n from public.messages where conversation_id = conv;
  log := log || format('[10e] F2 enxerga %s mensagens de conversa alheia (esperado 0)', n) || E'\n';

  reset role; perform pg_temp.act(f1);
  begin update public.profiles set plan='pro' where id=f1; log := log || '[11] FALHA: alterou o próprio plano' || E'\n';
  exception when others then log := log || '[11] não altera o próprio plano: OK' || E'\n'; end;
  begin update public.profiles set role='admin' where id=f1; log := log || '[11c] FALHA: virou admin' || E'\n';
  exception when others then log := log || '[11c] não vira admin: OK' || E'\n'; end;
  begin perform public.switch_role('admin'); log := log || '[11d] FALHA: switch_role admin' || E'\n';
  exception when others then log := log || '[11d] switch_role(admin) bloqueado: OK' || E'\n'; end;
  begin insert into public.subscriptions (user_id, asaas_subscription_id, billing_type) values (f1,'x','PIX'); log := log || '[11e] FALHA: criou assinatura' || E'\n';
  exception when others then log := log || '[11e] não cria assinatura direto: OK' || E'\n'; end;
  reset role; perform pg_temp.act(c);
  begin update public.jobs set featured_until = now() + interval '30 days' where id = job1; log := log || '[11g] FALHA: cliente se autodestacou' || E'\n';
  exception when others then log := log || '[11g] cliente não se autodestaca: OK' || E'\n'; end;

  -- cota do plano grátis (5/mês): F2 já tem 1; a 6ª deve falhar
  reset role;
  for i in 1..5 loop
    perform pg_temp.act(c);
    insert into public.jobs (client_id,title,category,description,budget_min,budget_max) values (c,'Vaga cota '||i,'Mobile','Descricao longa o bastante',1,2) returning id into j;
    reset role; perform pg_temp.act(f2);
    begin perform public.submit_proposal(j, 100, 5, 'cota', '[]'::jsonb); log := log || format('[12.%s] proposta %s aceita', i, i+1) || E'\n';
    exception when others then log := log || format('[12.%s] proposta %s bloqueada: %s (esperado só na 6ª)', i, i+1, sqlerrm) || E'\n'; end;
    reset role;
  end loop;

  raise exception E'RESULTADO — bloco 1\n%', log;
end $$;

-- ============================================================================
-- Bloco 2: múltiplos marcos, recusa/cancelamento, notificações e plano Pro
-- ============================================================================
do $$
declare
  c uuid := gen_random_uuid(); f1 uuid := gen_random_uuid(); f2 uuid := gen_random_uuid();
  log text := ''; job1 uuid; job2 uuid; job3 uuid; p1 uuid; p2 uuid; r jsonb; contract uuid;
  m1 uuid; m2 uuid; n int; s text;
begin
  insert into auth.users (id, email, raw_user_meta_data, aud, role) values
    (c,  'test-client@example.invalid', '{"full_name":"Cliente Teste","role":"client"}', 'authenticated','authenticated'),
    (f1, 'test-f1@example.invalid', '{"full_name":"Free Um","role":"freelancer"}', 'authenticated','authenticated'),
    (f2, 'test-f2@example.invalid', '{"full_name":"Free Dois","role":"freelancer"}', 'authenticated','authenticated');

  perform pg_temp.act(c);
  insert into public.jobs (client_id,title,category,description,budget_min,budget_max) values (c,'Vaga multi marcos','Mobile','Descricao longa o bastante',1000,5000) returning id into job1;
  insert into public.jobs (client_id,title,category,description,budget_min,budget_max) values (c,'Vaga recusa','Mobile','Descricao longa o bastante',1000,5000) returning id into job2;
  insert into public.jobs (client_id,title,category,description,budget_min,budget_max) values (c,'Vaga cancelar','Mobile','Descricao longa o bastante',1000,5000) returning id into job3;

  reset role; perform pg_temp.act(f1);
  select (public.submit_proposal(job1, 3000, 20, 'multi', '[{"title":"Design","amount":1000,"days":7},{"title":"Build","amount":2000,"days":13}]'::jsonb)).id into p1;
  perform public.submit_proposal(job2, 500, 5, 'recusada', '[]'::jsonb);
  reset role; perform pg_temp.act(f2);
  perform public.submit_proposal(job3, 700, 5, 'sera cancelada', '[]'::jsonb);

  reset role; perform pg_temp.act(c);
  r := public.accept_proposal(p1);
  contract := (r->>'contract_id')::uuid;
  reset role;
  select count(*) into n from public.milestones where contract_id = contract;
  log := log || format('[A1] marcos criados da proposta: %s (esperado 2)', n) || E'\n';
  select id into m1 from public.milestones where contract_id = contract order by sort_order limit 1;
  select id into m2 from public.milestones where contract_id = contract order by sort_order desc limit 1;

  perform pg_temp.act(c);
  begin perform public.approve_milestone(m1); log := log || '[A2] FALHA: aprovou sem entrega' || E'\n';
  exception when others then log := log || '[A2] aprovar sem entrega bloqueado: OK' || E'\n'; end;
  begin perform public.accept_proposal(p1); log := log || '[A2b] FALHA: aceitou 2x' || E'\n';
  exception when others then log := log || '[A2b] aceitar proposta já aceita bloqueado: OK' || E'\n'; end;

  reset role; perform pg_temp.act(f1);
  perform public.submit_deliverable(m1,'design pronto','[]'::jsonb);
  reset role; perform pg_temp.act(c);
  r := public.approve_milestone(m1);
  reset role;
  select status into s from public.contracts where id = contract;
  log := log || format('[A3] após 1 de 2 marcos: concluído=%s contrato=%s (esperado false/active)', r->>'contract_completed', s) || E'\n';
  perform pg_temp.act(f1);
  begin perform public.submit_deliverable(m1,'de novo','[]'::jsonb); log := log || '[A4] FALHA: entregou marco aprovado' || E'\n';
  exception when others then log := log || '[A4] entregar marco aprovado bloqueado: OK' || E'\n'; end;
  perform public.submit_deliverable(m2,'build pronto','[]'::jsonb);
  reset role; perform pg_temp.act(c);
  r := public.approve_milestone(m2);
  reset role;
  select status into s from public.contracts where id = contract;
  log := log || format('[A5] após o 2º marco: concluído=%s contrato=%s (esperado true/completed)', r->>'contract_completed', s) || E'\n';

  perform pg_temp.act(c);
  select id into p2 from public.proposals where job_id = job2;
  perform public.reject_proposal(p2);
  perform public.cancel_job(job3);
  select status into s from public.proposals where job_id = job3;
  log := log || format('[B2] proposta da vaga cancelada: %s (esperado rejected)', s) || E'\n';
  begin perform public.cancel_job(job1); log := log || '[B3] FALHA: cancelou vaga concluída' || E'\n';
  exception when others then log := log || '[B3] vaga concluída não cancela: OK' || E'\n'; end;
  update public.jobs set title='editada' where id = job1; get diagnostics n = row_count;
  log := log || format('[B4] editar vaga concluída afetou %s linhas (esperado 0)', n) || E'\n';
  reset role; perform pg_temp.act(f1);
  update public.jobs set title='invasor' where id = job2; get diagnostics n = row_count;
  log := log || format('[B6] freelancer editando vaga alheia: %s linhas (esperado 0)', n) || E'\n';
  begin perform public.submit_proposal(job2, 400, 5, 'de novo', '[]'::jsonb); log := log || '[B7] FALHA: reenviou após recusa' || E'\n';
  exception when others then log := log || '[B7] reenvio após recusa bloqueado: OK' || E'\n'; end;
  begin perform public.submit_proposal(job3, 400, 5, 'cancelada', '[]'::jsonb); log := log || '[B8] FALHA: propôs em vaga cancelada' || E'\n';
  exception when others then log := log || '[B8] proposta em vaga cancelada bloqueada: OK' || E'\n'; end;

  select public.mark_all_notifications_as_read() into n;
  select count(*) into n from public.notifications where not is_read;
  log := log || format('[C2] não lidas restantes: %s (esperado 0)', n) || E'\n';
  reset role; perform pg_temp.act(f2);
  select count(*) into n from public.notifications where user_id = f1;
  log := log || format('[C3] F2 enxerga %s notificações de F1 (esperado 0)', n) || E'\n';

  reset role;
  update public.profiles set plan='pro', plan_expires_at = now() + interval '10 days' where id = f2;
  perform pg_temp.act(f2); r := public.proposal_quota();
  log := log || format('[D1] Pro ativo: is_pro=%s limite=%s (esperado true/null)', r->>'is_pro', r->>'monthly_limit') || E'\n';
  reset role;
  update public.profiles set plan_expires_at = now() - interval '1 day' where id = f2;
  perform pg_temp.act(f2); r := public.proposal_quota();
  log := log || format('[D2] Pro vencido: is_pro=%s limite=%s (esperado false/5)', r->>'is_pro', r->>'monthly_limit') || E'\n';

  raise exception E'RESULTADO — bloco 2\n%', log;
end $$;
