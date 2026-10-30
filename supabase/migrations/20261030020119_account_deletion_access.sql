create function account_private.active_actor()
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.profiles where id=(select auth.uid()) and deleted_at is null);
$$;
grant usage on schema account_private to authenticated,service_role;
revoke all on function account_private.active_actor() from public,anon;
grant execute on function account_private.active_actor() to authenticated,service_role;

-- A trava compartilha a ordem com begin_account_deletion: uploads/mutações
-- iniciados antes precisam terminar antes de o pedido ser fechado para escrita.
create function account_private.guard_actor()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_active boolean; v_uid uuid:=auth.uid();
begin
  if v_uid is not null then
    select deleted_at is null into v_active from public.profiles where id=v_uid for share;
    if not coalesce(v_active,false) then raise exception 'ACCOUNT_DELETED' using errcode='42501'; end if;
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end;
$$;
revoke all on function account_private.guard_actor() from public,anon,authenticated,service_role;

do $$ declare t record;
begin
  for t in select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='r' and c.relrowsecurity
      and c.relname<>'account_deletion_requests'
  loop
    execute format('create trigger account_active_actor_guard before insert or update or delete on public.%I
      for each row execute function account_private.guard_actor()',t.relname);
    if t.relname<>'profiles' then
      execute format('create policy account_active_access on public.%I as restrictive for all to authenticated
        using ((select account_private.active_actor())) with check ((select account_private.active_actor()))',t.relname);
    end if;
  end loop;
end $$;

alter policy profiles_select on public.profiles using(
  deleted_at is null or id=(select auth.uid()) or exists(
    select 1 from public.contracts c where profiles.id in(c.client_id,c.freelancer_id)
      and (select auth.uid()) in(c.client_id,c.freelancer_id)));
alter policy profiles_update_own on public.profiles
  using(id=(select auth.uid()) and deleted_at is null)
  with check(id=(select auth.uid()) and deleted_at is null);

create trigger account_active_actor_guard before insert or update or delete on storage.objects
  for each row execute function account_private.guard_actor();
create policy account_active_access on storage.objects as restrictive for all to authenticated
  using((select account_private.active_actor())) with check((select account_private.active_actor()));
create policy resume_owner_active on storage.objects as restrictive for select to authenticated
  using(bucket_id<>'resumes' or exists(select 1 from public.profiles p
    where p.id::text=(storage.foldername(name))[1] and p.deleted_at is null));

create function account_private.guard_contract_participants()
returns trigger language plpgsql security definer set search_path='' as $$
declare p record;
begin
  if tg_op='INSERT' or new.status='active' then
    for p in select id,deleted_at from public.profiles
      where id in(new.client_id,new.freelancer_id) order by id for share
    loop
      if p.deleted_at is not null then raise exception 'DELETED_CONTRACT_PARTICIPANT'; end if;
    end loop;
  end if;
  return new;
end;
$$;
revoke all on function account_private.guard_contract_participants() from public,anon,authenticated,service_role;
create trigger account_contract_participants_guard before insert or update on public.contracts
  for each row execute function account_private.guard_contract_participants();

-- Coordena checkout e exclusão, inclusive chamadas de servidor já autenticadas.
create function account_private.guard_checkout_owner()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_active boolean;
begin
  select deleted_at is null into v_active from public.profiles where id=new.user_id for share;
  if not coalesce(v_active,false) then raise exception 'ACCOUNT_DELETED'; end if;
  return new;
end;
$$;
revoke all on function account_private.guard_checkout_owner() from public,anon,authenticated,service_role;
create trigger account_checkout_owner_guard before insert or update on public.billing_checkout_locks
  for each row execute function account_private.guard_checkout_owner();
