-- Volta de 20261117130000_chat_safety. Recusa se já houver denúncia de mensagem (perderia a
-- evidência guardada); bloqueios existentes são descartados.
do $$ begin
  if exists(select 1 from public.reports where target_type='message') then
    raise exception 'MESSAGE_REPORTS_PRESENT';
  end if;
end $$;

drop function public.report_message(uuid,text,text);
drop policy reports_insert_own on public.reports;
create policy reports_insert_own on public.reports
  for insert to authenticated
  with check (reporter_id = (select auth.uid()) and status = 'open');
alter table public.reports drop column evidence, drop column conversation_id;
alter table public.reports drop constraint reports_target_type_check;
alter table public.reports add constraint reports_target_type_check
  check (target_type in ('job', 'profile'));

create or replace function public.admin_list_reports(p_status text default 'open')
returns table (
  id uuid, target_type text, target_id uuid, target_label text, reason text,
  details text, status text, created_at timestamptz, reporter_id uuid,
  reporter_name text, reports_on_target bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  return query
  select r.id, r.target_type, r.target_id,
    case r.target_type
      when 'job' then (select j.title from public.jobs j where j.id = r.target_id)
      else (select p.full_name from public.profiles p where p.id = r.target_id)
    end,
    r.reason, r.details, r.status, r.created_at, r.reporter_id, rp.full_name,
    (select count(*) from public.reports o
      where o.target_type = r.target_type and o.target_id = r.target_id and o.status = 'open')
  from public.reports r
  left join public.profiles rp on rp.id = r.reporter_id
  where r.status = p_status
  order by r.created_at desc
  limit 200;
end;
$$;

create or replace function public.get_or_create_conversation(
  p_client_id uuid, p_freelancer_id uuid, p_job_id uuid default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if auth.uid() not in (p_client_id, p_freelancer_id) then
    raise exception 'FORBIDDEN';
  end if;
  select id into v_id from public.conversations
  where client_id = p_client_id and freelancer_id = p_freelancer_id
    and job_id is not distinct from p_job_id;
  if v_id is null then
    insert into public.conversations (client_id, freelancer_id, job_id)
    values (p_client_id, p_freelancer_id, p_job_id)
    on conflict do nothing
    returning id into v_id;
    if v_id is null then
      select id into v_id from public.conversations
      where client_id = p_client_id and freelancer_id = p_freelancer_id
        and job_id is not distinct from p_job_id;
    end if;
  end if;
  return v_id;
end;
$$;

drop trigger messages_block_guard on public.messages;
drop function public._messages_block_guard();
drop function public.unblock_user(uuid);
drop function public.block_user(uuid);
drop function public._blocked_between(uuid,uuid);
drop table public.user_blocks;
