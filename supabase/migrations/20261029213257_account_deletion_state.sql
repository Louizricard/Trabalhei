create schema account_private;
revoke all on schema account_private from public;
create table public.account_deletion_requests (
  user_id uuid primary key references auth.users(id) on delete cascade,
  hard_delete boolean not null,
  phase text not null default 'storage' check(phase in ('storage','auth','completed')),
  lease_token uuid,
  lease_until timestamptz,
  last_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.account_deletion_requests enable row level security;
revoke all on public.account_deletion_requests from public,anon,authenticated;
grant all on public.account_deletion_requests to service_role;

create function account_private.redact_profile(p_user uuid)
returns void language sql security definer set search_path='' as $$
  update public.profiles set full_name='Usuário removido',avatar_url=null,company_name=null,
    bio=null,hourly_rate=0,skills='{}',availability_status='unavailable',is_verified=false,
    plan='free',plan_expires_at=null,headline=null,location=null,website_url=null,
    linkedin_url=null,github_url=null,resume_url=null,deleted_at=coalesce(deleted_at,now())
    where id=p_user;
$$;
revoke all on function account_private.redact_profile(uuid) from public,anon,authenticated,service_role;

create function public.begin_account_deletion(p_user uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.account_deletion_requests; v_token uuid:=gen_random_uuid(); v_hard boolean;
begin
  perform 1 from public.profiles where id=p_user for update;
  if not found then
    if not exists(select 1 from auth.users where id=p_user) then return '{"completed":true}'::jsonb; end if;
    raise exception 'PROFILE_NOT_FOUND';
  end if;
  select * into r from public.account_deletion_requests where user_id=p_user for update;
  if found then
    if r.phase='completed' then return '{"completed":true}'::jsonb; end if;
    if r.lease_until>now() then raise exception 'DELETION_BUSY'; end if;
  else
    if exists(select 1 from public.billing_checkout_locks where user_id=p_user and expires_at>now())
      or exists(select 1 from public.billing_checkouts c where c.user_id=p_user and c.result is null
        and exists(select 1 from public.billing_checkout_steps s where s.user_id=p_user
          and s.step_key in(c.id||':subscription',c.id||':payment')))
      then raise exception 'DELETION_BILLING_PENDING'; end if;
    if exists(select 1 from public.contracts where status='active' and p_user in(client_id,freelancer_id))
      then raise exception 'ACTIVE_CONTRACTS'; end if;
    v_hard:=not exists(select 1 from public.contracts where p_user in(client_id,freelancer_id));
    insert into public.account_deletion_requests(user_id,hard_delete) values(p_user,v_hard) returning * into r;
  end if;
  perform account_private.redact_profile(p_user);
  update public.account_deletion_requests set lease_token=v_token,lease_until=now()+interval '120 seconds',
    last_error_code=null,updated_at=now() where user_id=p_user;
  return jsonb_build_object('token',v_token,'hard_delete',r.hard_delete,'phase',r.phase,'completed',false);
end;
$$;

create function account_private.deletion_request(p_user uuid,p_token uuid)
returns public.account_deletion_requests language plpgsql security definer set search_path='' as $$
declare r public.account_deletion_requests;
begin
  select * into strict r from public.account_deletion_requests where user_id=p_user for update;
  if r.lease_token is distinct from p_token or coalesce(r.lease_until,now())<=now()
    then raise exception 'DELETION_LEASE_LOST'; end if;
  update public.account_deletion_requests set lease_until=now()+interval '120 seconds',updated_at=now() where user_id=p_user;
  return r;
end;
$$;
revoke all on function account_private.deletion_request(uuid,uuid) from public,anon,authenticated,service_role;

create function public.fail_account_deletion(p_user uuid,p_token uuid,p_code text)
returns void language sql security definer set search_path='' as $$
  update public.account_deletion_requests set lease_token=null,lease_until=null,
    last_error_code=case when p_code in('billing','storage','data','auth','complete') then p_code else 'unknown' end,
    updated_at=now() where user_id=p_user and lease_token=p_token and phase<>'completed';
$$;
create function public.complete_account_deletion(p_user uuid,p_token uuid)
returns void language plpgsql security definer set search_path='' as $$
declare r public.account_deletion_requests;
begin
  if not exists(select 1 from auth.users where id=p_user) then return; end if;
  r:=account_private.deletion_request(p_user,p_token);
  if r.phase<>'auth' then raise exception 'DELETION_NOT_READY'; end if;
  update public.account_deletion_requests set phase='completed',lease_token=null,lease_until=null,
    last_error_code=null,updated_at=now() where user_id=p_user;
end;
$$;
revoke all on function public.begin_account_deletion(uuid),public.fail_account_deletion(uuid,uuid,text),
  public.complete_account_deletion(uuid,uuid) from public,anon,authenticated;
grant execute on function public.begin_account_deletion(uuid),public.fail_account_deletion(uuid,uuid,text),
  public.complete_account_deletion(uuid,uuid) to service_role;
