-- Segurança no chat: bloquear usuário e denunciar mensagem. Bloqueio vale nos dois sentidos para
-- mensagens e para abrir conversa nova; mensagens de sistema do contrato continuam passando.
-- Detalhes: docs/moderacao-chat.md. Volta: rollbacks/20261117130000_chat_safety_down.sql.

create table public.user_blocks(
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(blocker_id,blocked_id),
  check(blocker_id<>blocked_id)
);
create index user_blocks_blocked_idx on public.user_blocks(blocked_id);
alter table public.user_blocks enable row level security;
create policy user_blocks_select_own on public.user_blocks
  for select to authenticated using (blocker_id=(select auth.uid()));
revoke all on public.user_blocks from public,anon,authenticated;
grant select on public.user_blocks to authenticated;
grant all on public.user_blocks to service_role;

create function public._blocked_between(p_a uuid,p_b uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.user_blocks
    where (blocker_id=p_a and blocked_id=p_b) or (blocker_id=p_b and blocked_id=p_a));
$$;
revoke all on function public._blocked_between(uuid,uuid) from public,anon,authenticated;

create function public.block_user(p_user uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();
begin
  if v_uid is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if p_user is null or p_user=v_uid then raise exception 'INVALID_BLOCK'; end if;
  perform 1 from public.profiles where id=p_user;
  if not found then raise exception 'USER_NOT_FOUND'; end if;
  insert into public.user_blocks(blocker_id,blocked_id) values(v_uid,p_user) on conflict do nothing;
end;
$$;

create function public.unblock_user(p_user uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  delete from public.user_blocks where blocker_id=auth.uid() and blocked_id=p_user;
end;
$$;

-- Mensagem de pessoa (texto/arquivo) entre bloqueados é recusada; eventos de sistema passam.
create function public._messages_block_guard()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_other uuid;
begin
  if new.message_type not in('text','image','file','document') then return new; end if;
  select case when c.client_id=new.sender_id then c.freelancer_id else c.client_id end
    into v_other from public.conversations c where c.id=new.conversation_id;
  if v_other is not null and public._blocked_between(new.sender_id,v_other) then
    raise exception 'USER_BLOCKED';
  end if;
  return new;
end;
$$;
revoke all on function public._messages_block_guard() from public,anon,authenticated;
create trigger messages_block_guard before insert on public.messages
  for each row execute function public._messages_block_guard();

create or replace function public.get_or_create_conversation(
  p_client_id uuid, p_freelancer_id uuid, p_job_id uuid default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if auth.uid() not in (p_client_id, p_freelancer_id) then
    raise exception 'FORBIDDEN';
  end if;
  if public._blocked_between(p_client_id, p_freelancer_id) then
    raise exception 'USER_BLOCKED';
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

-- Denúncia de mensagem: só quem participa da conversa denuncia mensagem da outra parte. O
-- conteúdo é copiado para a denúncia (evidence), assim a moderação vê só o que foi denunciado.
alter table public.reports drop constraint reports_target_type_check;
alter table public.reports add constraint reports_target_type_check
  check(target_type in('job','profile','message'));
alter table public.reports
  add column conversation_id uuid references public.conversations(id) on delete set null,
  add column evidence jsonb;
create index reports_conversation_idx on public.reports(conversation_id);
drop policy reports_insert_own on public.reports;
create policy reports_insert_own on public.reports
  for insert to authenticated
  with check (reporter_id=(select auth.uid()) and status='open' and target_type in('job','profile')
    and conversation_id is null and evidence is null);

create function public.report_message(p_message_id uuid,p_reason text,p_details text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); m public.messages; v_id uuid;
begin
  if v_uid is null then raise exception 'NOT_AUTHENTICATED'; end if;
  select msg.* into m from public.messages msg join public.conversations c on c.id=msg.conversation_id
    where msg.id=p_message_id and v_uid in(c.client_id,c.freelancer_id) and msg.sender_id<>v_uid
      and msg.message_type in('text','image','file','document');
  if not found then raise exception 'MESSAGE_NOT_FOUND'; end if;
  insert into public.reports(reporter_id,target_type,target_id,reason,details,conversation_id,evidence)
  values(v_uid,'message',m.id,p_reason,nullif(trim(p_details),''),m.conversation_id,jsonb_build_object(
    'sender_id',m.sender_id,'content',left(m.content,2000),'message_type',m.message_type,
    'attachment_name',m.attachment_name,'sent_at',m.created_at))
  on conflict(reporter_id,target_type,target_id) where status='open' do nothing
  returning id into v_id;
  if v_id is null then
    select id into v_id from public.reports where reporter_id=v_uid and target_type='message'
      and target_id=m.id and status='open';
  end if;
  return v_id;
end;
$$;

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
  select r.id, r.target_type,
    -- Denúncia de mensagem aponta para quem enviou: é quem a moderação pode suspender.
    case when r.target_type = 'message' then (r.evidence->>'sender_id')::uuid else r.target_id end,
    case r.target_type
      when 'job' then (select j.title from public.jobs j where j.id = r.target_id)
      when 'message' then coalesce((select p.full_name from public.profiles p
          where p.id = (r.evidence->>'sender_id')::uuid), 'Usuário') || ': "' ||
        left(coalesce(nullif(r.evidence->>'content', ''), r.evidence->>'attachment_name', '(anexo)'), 280) || '"'
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

revoke all on function public.block_user(uuid), public.unblock_user(uuid),
  public.report_message(uuid,text,text) from public,anon;
grant execute on function public.block_user(uuid), public.unblock_user(uuid),
  public.report_message(uuid,text,text) to authenticated;
