-- Volta de 20261112213744_hiring_journey_fixes. Recusa se já houver contrato
-- encerrado pela RPC nova: as colunas de motivo seriam apagadas.
do $$ begin
  if exists (select 1 from public.contracts where cancelled_at is not null) then
    raise exception 'CANCELLED_CONTRACTS_PRESENT';
  end if;
end $$;

drop function public.cancel_contract(uuid, text);
drop function public.accept_proposal(uuid, numeric);

-- Definições anteriores (20261015211818_initial_schema e 20261026162219_plans_and_limits).
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
begin
  if v_uid is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not exists (select 1 from public.profiles where id = v_uid and role = 'freelancer') then
    raise exception 'ONLY_FREELANCERS_CAN_APPLY';
  end if;

  select * into v_job from public.jobs where id = p_job_id;
  if not found or v_job.status <> 'open' then raise exception 'JOB_NOT_OPEN'; end if;
  if v_job.client_id = v_uid then raise exception 'CANNOT_APPLY_TO_OWN_JOB'; end if;
  if char_length(trim(coalesce(p_cover_letter, ''))) < s.min_cover_letter_chars then
    raise exception 'COVER_LETTER_TOO_SHORT';
  end if;

  select * into v_existing from public.proposals
  where job_id = p_job_id and freelancer_id = v_uid for update;

  if found then
    if v_existing.status not in ('pending', 'counter_offered') then
      raise exception 'PROPOSAL_ALREADY_DECIDED';
    end if;
    update public.proposals set
      bid_amount = p_bid_amount, estimated_days = p_estimated_days,
      cover_letter = coalesce(p_cover_letter, ''), proposed_milestones = coalesce(p_milestones, '[]'::jsonb),
      status = 'pending', counter_price = null, counter_estimated_days = null,
      counter_message = null, counter_by_user_id = null, counter_created_at = null
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
  values (p_job_id, v_uid, p_bid_amount, p_estimated_days, coalesce(p_cover_letter, ''), coalesce(p_milestones, '[]'::jsonb))
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

  -- Marcos propostos só valem se somarem o valor acordado; senão, marco único.
  select coalesce(sum((m ->> 'amount')::numeric), 0) into v_sum
  from jsonb_array_elements(v_prop.proposed_milestones) m;
  if jsonb_array_length(v_prop.proposed_milestones) > 0 and v_sum = v_prop.bid_amount then
    v_ms := v_prop.proposed_milestones;
  else
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

create or replace function public.accept_proposal(p_proposal_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_prop public.proposals;
begin
  select p.* into v_prop from public.proposals p
  join public.jobs j on j.id = p.job_id
  where p.id = p_proposal_id and j.client_id = auth.uid();
  if not found then raise exception 'PROPOSAL_NOT_FOUND'; end if;
  if v_prop.status <> 'pending' then raise exception 'PROPOSAL_NOT_PENDING'; end if;
  return public._create_contract(p_proposal_id);
end;
$$;
revoke execute on function public.accept_proposal(uuid) from public, anon;
grant execute on function public.accept_proposal(uuid) to authenticated;

create or replace function public.reject_proposal(p_proposal_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_prop public.proposals; v_job public.jobs;
begin
  select p.* into v_prop from public.proposals p
  join public.jobs j on j.id = p.job_id
  where p.id = p_proposal_id and j.client_id = auth.uid();
  if not found then raise exception 'PROPOSAL_NOT_FOUND'; end if;
  if v_prop.status not in ('pending', 'counter_offered') then
    raise exception 'PROPOSAL_ALREADY_DECIDED';
  end if;
  update public.proposals set status = 'rejected' where id = p_proposal_id;
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
  where p.id = p_proposal_id and j.client_id = auth.uid();
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
  where id = p_proposal_id;
  select * into v_job from public.jobs where id = v_prop.job_id;
  perform public.notify(v_prop.freelancer_id, 'proposal_received', 'Você recebeu uma contraproposta',
    'O cliente enviou uma contraproposta para "' || v_job.title || '".',
    jsonb_build_object('job_id', v_job.id, 'proposal_id', p_proposal_id,
                       'route', '/jobs/' || v_job.id || '/apply'));
end;
$$;

create or replace function public.request_revision(
  p_milestone_id uuid, p_comment text, p_attachments jsonb default '[]'::jsonb
) returns void language plpgsql security definer set search_path = public as $$
declare ctx record; v_status text;
begin
  if p_comment is null or length(trim(p_comment)) = 0 then raise exception 'COMMENT_REQUIRED'; end if;
  select * into ctx from public._milestone_context(p_milestone_id);
  if not found or ctx.client_id <> auth.uid() then raise exception 'MILESTONE_NOT_FOUND'; end if;
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
  end if;
  return jsonb_build_object('contract_completed', v_completed);
end;
$$;

drop function public._proposed_milestones_total(jsonb);
alter table public.contracts
  drop column cancel_reason,
  drop column cancelled_by,
  drop column cancelled_at;
