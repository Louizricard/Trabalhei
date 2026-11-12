-- Jornada de contratação: travas de concorrência, validação de marcos, aceite
-- com valor esperado, contratação após contraproposta e encerramento de contrato.
-- Detalhes e regras: docs/contratacao.md. Volta: rollbacks/20261112120000_hiring_journey_fixes_down.sql.

-- ---------------------------------------------------------------- Encerramento
-- Quem encerrou, quando e por quê. Visível às duas partes pela policy
-- contracts_select existente; escrita só pela RPC cancel_contract.
alter table public.contracts
  add column cancelled_at timestamptz,
  add column cancelled_by uuid references public.profiles (id) on delete set null,
  add column cancel_reason text check (cancel_reason is null or char_length(cancel_reason) between 10 and 500);

-- ---------------------------------------------------------------- Marcos propostos
-- Soma dos marcos se a lista for válida (array de objetos com título, valor
-- positivo de até 2 casas e prazo inteiro de 1 a 3650 dias, no máximo 20);
-- null se malformada. Lista vazia soma 0.
create function public._proposed_milestones_total(p jsonb)
returns numeric language plpgsql immutable set search_path = '' as $$
declare e jsonb; v_total numeric := 0; v_amount numeric; v_days numeric;
begin
  if p is null or jsonb_typeof(p) <> 'array' or jsonb_array_length(p) > 20 then return null; end if;
  for e in select value from jsonb_array_elements(p) loop
    if jsonb_typeof(e) <> 'object'
       or coalesce(jsonb_typeof(e -> 'title'), '') <> 'string'
       or char_length(trim(e ->> 'title')) not between 1 and 120
       or coalesce(jsonb_typeof(e -> 'amount'), '') <> 'number'
       or coalesce(jsonb_typeof(e -> 'days'), '') <> 'number' then
      return null;
    end if;
    v_amount := (e ->> 'amount')::numeric;
    v_days := (e ->> 'days')::numeric;
    if v_amount <= 0 or v_amount <> round(v_amount, 2)
       or v_days <> trunc(v_days) or v_days not between 1 and 3650 then
      return null;
    end if;
    v_total := v_total + v_amount;
  end loop;
  return v_total;
end;
$$;
revoke execute on function public._proposed_milestones_total(jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------- Envio de proposta
-- Mudanças: trava por freelancer antes de contar a cota (envios paralelos
-- não furam o limite), marcos validados e reenvio bloqueado enquanto houver
-- contraproposta do cliente sem resposta.
create or replace function public.submit_proposal(
  p_job_id uuid, p_bid_amount numeric, p_estimated_days integer,
  p_cover_letter text, p_milestones jsonb default '[]'::jsonb
)
returns public.proposals
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.platform_settings := public.settings();
  v_uid uuid := auth.uid();
  v_job public.jobs;
  v_existing public.proposals;
  v_result public.proposals;
  v_limit integer;
  v_name text;
  v_milestones jsonb := coalesce(p_milestones, '[]'::jsonb);
  v_total numeric;
begin
  if v_uid is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not exists (select 1 from public.profiles where id = v_uid and role = 'freelancer') then
    raise exception 'ONLY_FREELANCERS_CAN_APPLY';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('submit_proposal:' || v_uid::text, 0));

  select * into v_job from public.jobs where id = p_job_id;
  if not found or v_job.status <> 'open' then raise exception 'JOB_NOT_OPEN'; end if;
  if v_job.client_id = v_uid then raise exception 'CANNOT_APPLY_TO_OWN_JOB'; end if;
  if char_length(trim(coalesce(p_cover_letter, ''))) < s.min_cover_letter_chars then
    raise exception 'COVER_LETTER_TOO_SHORT';
  end if;
  v_total := public._proposed_milestones_total(v_milestones);
  if v_total is null or (jsonb_array_length(v_milestones) > 0 and v_total <> p_bid_amount) then
    raise exception 'INVALID_MILESTONES';
  end if;

  select * into v_existing from public.proposals
  where job_id = p_job_id and freelancer_id = v_uid for update;

  if found then
    if v_existing.status = 'counter_offered' then
      raise exception 'COUNTER_OFFER_PENDING';
    end if;
    if v_existing.status <> 'pending' then
      raise exception 'PROPOSAL_ALREADY_DECIDED';
    end if;
    update public.proposals set
      bid_amount = p_bid_amount, estimated_days = p_estimated_days,
      cover_letter = coalesce(p_cover_letter, ''), proposed_milestones = v_milestones
    where id = v_existing.id returning * into v_result;
    return v_result;
  end if;

  -- Envio em massa: teto por 24 h vale para todos os planos.
  if (select count(*) from public.proposals
      where freelancer_id = v_uid and created_at > now() - interval '24 hours') >= s.daily_proposals then
    raise exception 'DAILY_PROPOSAL_LIMIT';
  end if;

  v_limit := case when public.is_pro(v_uid) then s.pro_monthly_proposals else s.free_monthly_proposals end;
  if public.counted_proposals(v_uid, date_trunc('month', now())) >= v_limit then
    raise exception 'PROPOSAL_QUOTA_EXCEEDED';
  end if;

  insert into public.proposals (job_id, freelancer_id, bid_amount, estimated_days, cover_letter, proposed_milestones)
  values (p_job_id, v_uid, p_bid_amount, p_estimated_days, coalesce(p_cover_letter, ''), v_milestones)
  returning * into v_result;

  select full_name into v_name from public.profiles where id = v_uid;
  perform public.notify(
    v_job.client_id, 'proposal_received', 'Nova proposta recebida',
    coalesce(v_name, 'Um freelancer') || ' enviou uma proposta para "' || v_job.title || '".',
    jsonb_build_object('job_id', v_job.id, 'proposal_id', v_result.id,
                       'route', '/jobs/' || v_job.id || '/proposals')
  );
  return v_result;
end;
$$;

-- ---------------------------------------------------------------- Criação do contrato
-- Mudança: marcos propostos que não somam o valor final (contraproposta
-- aceita) são redimensionados proporcionalmente; o último absorve o
-- arredondamento. Lista malformada (anterior à validação) vira marco único.
create or replace function public._create_contract(p_proposal_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_prop public.proposals;
  v_job public.jobs;
  v_contract_id uuid;
  v_conv_id uuid;
  v_sum numeric;
  v_ms jsonb;
begin
  select * into v_prop from public.proposals where id = p_proposal_id for update;
  select * into v_job from public.jobs where id = v_prop.job_id for update;
  if v_job.status <> 'open' then raise exception 'JOB_NOT_OPEN'; end if;

  insert into public.contracts (job_id, proposal_id, client_id, freelancer_id, total_amount, estimated_days)
  values (v_job.id, v_prop.id, v_job.client_id, v_prop.freelancer_id, v_prop.bid_amount, v_prop.estimated_days)
  returning id into v_contract_id;

  v_sum := public._proposed_milestones_total(v_prop.proposed_milestones);
  if v_sum is not null and v_sum > 0 and v_sum <> v_prop.bid_amount then
    select jsonb_agg(
             m.elem || jsonb_build_object('amount',
               case when m.ord = m.total then v_prop.bid_amount - m.prior
                    else round((m.elem ->> 'amount')::numeric * v_prop.bid_amount / v_sum, 2) end)
             order by m.ord)
    into v_ms
    from (
      select x.elem, x.ord, count(*) over () as total,
             coalesce(sum(round((x.elem ->> 'amount')::numeric * v_prop.bid_amount / v_sum, 2))
               over (order by x.ord rows between unbounded preceding and 1 preceding), 0) as prior
      from jsonb_array_elements(v_prop.proposed_milestones) with ordinality as x(elem, ord)
    ) m;
    if exists (select 1 from jsonb_array_elements(v_ms) e where (e ->> 'amount')::numeric <= 0) then
      v_ms := null;
    end if;
  elsif v_sum is not null and v_sum > 0 then
    v_ms := v_prop.proposed_milestones;
  end if;
  if v_ms is null then
    v_ms := jsonb_build_array(jsonb_build_object(
      'title', 'Entrega do projeto', 'amount', v_prop.bid_amount, 'days', v_prop.estimated_days));
  end if;

  insert into public.milestones (contract_id, title, amount, sort_order, due_date)
  select v_contract_id,
         coalesce(nullif(m.elem ->> 'title', ''), 'Marco ' || m.ord),
         coalesce((m.elem ->> 'amount')::numeric, 0),
         m.ord,
         current_date + coalesce((m.elem ->> 'days')::int, v_prop.estimated_days)
  from jsonb_array_elements(v_ms) with ordinality as m(elem, ord);

  update public.proposals set status = 'accepted' where id = v_prop.id;
  update public.proposals set status = 'rejected'
  where job_id = v_job.id and id <> v_prop.id and status in ('pending', 'counter_offered');
  update public.jobs set status = 'in_progress' where id = v_job.id;

  v_conv_id := public.get_or_create_conversation_internal(v_job.client_id, v_prop.freelancer_id, v_job.id);
  update public.conversations set contract_id = v_contract_id where id = v_conv_id;

  perform public._system_message(v_conv_id, v_job.client_id,
    '🤝 Contrato iniciado para "' || v_job.title || '". Combinem prazos e forma de pagamento aqui no chat.');
  perform public.notify(
    v_prop.freelancer_id, 'proposal_accepted', 'Proposta aceita! 🎉',
    'Sua proposta para "' || v_job.title || '" foi aceita.',
    jsonb_build_object('job_id', v_job.id, 'contract_id', v_contract_id,
                       'conversation_id', v_conv_id, 'route', '/chat/' || v_conv_id)
  );
  return jsonb_build_object('contract_id', v_contract_id, 'conversation_id', v_conv_id);
end;
$$;

-- ---------------------------------------------------------------- Aceite pelo cliente
-- Mudanças: p_expected_amount (o valor que o cliente viu) é comparado sob
-- trava e diverge com PROPOSAL_CHANGED; null mantém o comportamento das
-- versões antigas do app. Proposta com contraproposta do próprio cliente pode
-- ser aceita pelo valor original da proposta, descartando a contraproposta.
drop function public.accept_proposal(uuid);
create function public.accept_proposal(p_proposal_id uuid, p_expected_amount numeric default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_prop public.proposals; v_result jsonb;
begin
  select p.* into v_prop from public.proposals p
  join public.jobs j on j.id = p.job_id
  where p.id = p_proposal_id and j.client_id = auth.uid()
  for update of p;
  if not found then raise exception 'PROPOSAL_NOT_FOUND'; end if;
  if v_prop.status not in ('pending', 'counter_offered') then raise exception 'PROPOSAL_NOT_PENDING'; end if;
  if p_expected_amount is not null and p_expected_amount <> v_prop.bid_amount then
    raise exception 'PROPOSAL_CHANGED';
  end if;
  v_result := public._create_contract(p_proposal_id);
  if v_prop.status = 'counter_offered' then
    perform public._system_message((v_result ->> 'conversation_id')::uuid, auth.uid(),
      'O cliente contratou pelo valor original da proposta (R$ '
      || to_char(v_prop.bid_amount, 'FM999G999G990D00') || '); a contraproposta foi descartada.');
  end if;
  return v_result;
end;
$$;
revoke execute on function public.accept_proposal(uuid, numeric) from public, anon;
grant execute on function public.accept_proposal(uuid, numeric) to authenticated;

-- ---------------------------------------------------------------- Recusa e contraproposta
-- Mudança: proposta travada antes de checar o estado; a atualização só vale
-- se ela continuar em aberto (não sobrescreve aceite concorrente).
create or replace function public.reject_proposal(p_proposal_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_prop public.proposals; v_job public.jobs;
begin
  select p.* into v_prop from public.proposals p
  join public.jobs j on j.id = p.job_id
  where p.id = p_proposal_id and j.client_id = auth.uid()
  for update of p;
  if not found then raise exception 'PROPOSAL_NOT_FOUND'; end if;
  if v_prop.status not in ('pending', 'counter_offered') then
    raise exception 'PROPOSAL_ALREADY_DECIDED';
  end if;
  update public.proposals set status = 'rejected'
  where id = p_proposal_id and status in ('pending', 'counter_offered');
  if not found then raise exception 'PROPOSAL_ALREADY_DECIDED'; end if;
  select * into v_job from public.jobs where id = v_prop.job_id;
  perform public.notify(v_prop.freelancer_id, 'system', 'Proposta não selecionada',
    'Sua proposta para "' || v_job.title || '" não foi selecionada.',
    jsonb_build_object('job_id', v_job.id, 'route', '/jobs/' || v_job.id));
end;
$$;

create or replace function public.make_counter_offer(
  p_proposal_id uuid, p_price numeric, p_days int, p_message text default null
) returns void language plpgsql security definer set search_path = public as $$
declare v_prop public.proposals; v_job public.jobs;
begin
  select p.* into v_prop from public.proposals p
  join public.jobs j on j.id = p.job_id
  where p.id = p_proposal_id and j.client_id = auth.uid()
  for update of p;
  if not found then raise exception 'PROPOSAL_NOT_FOUND'; end if;
  if v_prop.status not in ('pending', 'counter_offered') then
    raise exception 'PROPOSAL_ALREADY_DECIDED';
  end if;
  if p_price is null or p_price <= 0 or p_days is null or p_days <= 0 then
    raise exception 'INVALID_COUNTER_OFFER';
  end if;
  update public.proposals set
    status = 'counter_offered', counter_price = p_price, counter_estimated_days = p_days,
    counter_message = nullif(trim(coalesce(p_message, '')), ''),
    counter_by_user_id = auth.uid(), counter_created_at = now()
  where id = p_proposal_id and status in ('pending', 'counter_offered');
  if not found then raise exception 'PROPOSAL_ALREADY_DECIDED'; end if;
  select * into v_job from public.jobs where id = v_prop.job_id;
  perform public.notify(v_prop.freelancer_id, 'proposal_received', 'Você recebeu uma contraproposta',
    'O cliente enviou uma contraproposta para "' || v_job.title || '".',
    jsonb_build_object('job_id', v_job.id, 'proposal_id', p_proposal_id,
                       'route', '/jobs/' || v_job.id || '/apply'));
end;
$$;

-- ---------------------------------------------------------------- Marcos
-- Mudanças: contrato travado antes do marco (aprovações simultâneas não
-- deixam o contrato preso em active) e exigido como active; freelancer
-- também recebe o aviso de conclusão para avaliar o cliente.
create or replace function public.request_revision(
  p_milestone_id uuid, p_comment text, p_attachments jsonb default '[]'::jsonb
) returns void language plpgsql security definer set search_path = public as $$
declare ctx record; v_status text;
begin
  if p_comment is null or length(trim(p_comment)) = 0 then raise exception 'COMMENT_REQUIRED'; end if;
  select * into ctx from public._milestone_context(p_milestone_id);
  if not found or ctx.client_id <> auth.uid() then raise exception 'MILESTONE_NOT_FOUND'; end if;
  perform 1 from public.contracts where id = ctx.contract_id and status = 'active' for update;
  if not found then raise exception 'CONTRACT_NOT_ACTIVE'; end if;
  select status into v_status from public.milestones where id = p_milestone_id for update;
  if v_status <> 'submitted' then raise exception 'MILESTONE_NOT_SUBMITTED'; end if;
  insert into public.milestone_revisions (milestone_id, contract_id, requested_by, comment, attachments)
  values (p_milestone_id, ctx.contract_id, auth.uid(), trim(p_comment), coalesce(p_attachments, '[]'::jsonb));
  update public.milestones set status = 'in_revision', revision_count = revision_count + 1
  where id = p_milestone_id;
  if ctx.conversation_id is not null then
    perform public._system_message(ctx.conversation_id, auth.uid(),
      '🔄 Revisão solicitada no marco "' || ctx.title || '":' || E'\n\n"' || trim(p_comment) || '"');
  end if;
  perform public.notify(ctx.freelancer_id, 'milestone_in_revision', 'Ajustes solicitados',
    'O cliente pediu ajustes no marco "' || ctx.title || '".',
    jsonb_build_object('contract_id', ctx.contract_id, 'milestone_id', p_milestone_id,
                       'conversation_id', ctx.conversation_id,
                       'route', '/chat/' || coalesce(ctx.conversation_id::text, '')));
end;
$$;

create or replace function public.approve_milestone(p_milestone_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare ctx record; v_status text; v_pending int; v_completed boolean := false;
begin
  select * into ctx from public._milestone_context(p_milestone_id);
  if not found or ctx.client_id <> auth.uid() then raise exception 'MILESTONE_NOT_FOUND'; end if;
  perform 1 from public.contracts where id = ctx.contract_id and status = 'active' for update;
  if not found then raise exception 'CONTRACT_NOT_ACTIVE'; end if;
  select status into v_status from public.milestones where id = p_milestone_id for update;
  if v_status <> 'submitted' then raise exception 'MILESTONE_NOT_SUBMITTED'; end if;
  update public.milestones set status = 'approved', approved_at = now() where id = p_milestone_id;

  if ctx.conversation_id is not null then
    perform public._system_message(ctx.conversation_id, auth.uid(),
      '🎉 Marco "' || ctx.title || '" aprovado pelo cliente!');
  end if;
  perform public.notify(ctx.freelancer_id, 'milestone_approved', 'Entrega aprovada 🎉',
    'O marco "' || ctx.title || '" foi aprovado.',
    jsonb_build_object('contract_id', ctx.contract_id, 'milestone_id', p_milestone_id,
                       'conversation_id', ctx.conversation_id,
                       'route', '/chat/' || coalesce(ctx.conversation_id::text, '')));

  select count(*) into v_pending from public.milestones
  where contract_id = ctx.contract_id and status <> 'approved';
  if v_pending = 0 then
    update public.contracts set status = 'completed', completed_at = now()
    where id = ctx.contract_id and status = 'active';
    update public.jobs set status = 'completed'
    where id = (select job_id from public.contracts where id = ctx.contract_id);
    update public.profiles set completed_jobs_count = completed_jobs_count + 1
    where id = ctx.freelancer_id;
    v_completed := true;
    if ctx.conversation_id is not null then
      perform public._system_message(ctx.conversation_id, auth.uid(),
        '✅ Projeto concluído! Deixe sua avaliação para a outra parte.');
    end if;
    perform public.notify(ctx.client_id, 'system', 'Projeto concluído',
      '"' || ctx.job_title || '" foi concluído. Avalie o freelancer!',
      jsonb_build_object('contract_id', ctx.contract_id, 'conversation_id', ctx.conversation_id,
                         'route', '/chat/' || coalesce(ctx.conversation_id::text, '')));
    perform public.notify(ctx.freelancer_id, 'system', 'Projeto concluído',
      '"' || ctx.job_title || '" foi concluído. Avalie o cliente!',
      jsonb_build_object('contract_id', ctx.contract_id, 'conversation_id', ctx.conversation_id,
                         'route', '/chat/' || coalesce(ctx.conversation_id::text, '')));
  end if;
  return jsonb_build_object('contract_completed', v_completed);
end;
$$;

-- ---------------------------------------------------------------- Encerramento de contrato
-- Cliente ou freelancer encerra um contrato ativo informando o motivo
-- (10 a 500 caracteres). Sem custódia de valores, não há reembolso a tratar.
-- A vaga vai para cancelled, a outra parte é notificada e o chat registra.
create function public.cancel_contract(p_contract_id uuid, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_contract public.contracts;
  v_reason text := trim(coalesce(p_reason, ''));
  v_job_title text;
  v_conv_id uuid;
  v_other uuid;
  v_role text;
begin
  select * into v_contract from public.contracts
  where id = p_contract_id and v_uid in (client_id, freelancer_id) for update;
  if not found then raise exception 'CONTRACT_NOT_FOUND'; end if;
  if v_contract.status <> 'active' then raise exception 'CONTRACT_NOT_ACTIVE'; end if;
  if char_length(v_reason) not between 10 and 500 then raise exception 'CANCEL_REASON_REQUIRED'; end if;

  update public.contracts set
    status = 'cancelled', cancelled_at = now(), cancelled_by = v_uid, cancel_reason = v_reason
  where id = p_contract_id;
  update public.jobs set status = 'cancelled'
  where id = v_contract.job_id and status = 'in_progress'
  returning title into v_job_title;
  if v_job_title is null then
    select title into v_job_title from public.jobs where id = v_contract.job_id;
  end if;

  v_other := case when v_uid = v_contract.client_id then v_contract.freelancer_id else v_contract.client_id end;
  v_role := case when v_uid = v_contract.client_id then 'cliente' else 'freelancer' end;
  select id into v_conv_id from public.conversations where contract_id = p_contract_id limit 1;
  if v_conv_id is not null then
    perform public._system_message(v_conv_id, v_uid,
      '⛔ Contrato encerrado pelo ' || v_role || '. Motivo:' || E'\n\n"' || v_reason || '"');
  end if;
  perform public.notify(v_other, 'system', 'Contrato encerrado',
    'O contrato de "' || coalesce(v_job_title, 'sua vaga') || '" foi encerrado pelo ' || v_role || '.',
    jsonb_build_object('contract_id', p_contract_id, 'job_id', v_contract.job_id,
                       'conversation_id', v_conv_id,
                       'route', '/chat/' || coalesce(v_conv_id::text, '')));
end;
$$;
revoke execute on function public.cancel_contract(uuid, text) from public, anon;
grant execute on function public.cancel_contract(uuid, text) to authenticated;
