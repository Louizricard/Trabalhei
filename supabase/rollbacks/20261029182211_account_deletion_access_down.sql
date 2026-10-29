do $$ begin
  if exists(select 1 from public.account_deletion_requests) then raise exception 'ACCOUNT_DELETION_DATA_PRESENT'; end if;
end $$;
drop trigger account_checkout_owner_guard on public.billing_checkout_locks;
drop function account_private.guard_checkout_owner();
drop trigger account_contract_participants_guard on public.contracts;
drop function account_private.guard_contract_participants();
drop policy resume_owner_active on storage.objects;
drop policy account_active_access on storage.objects;
drop trigger account_active_actor_guard on storage.objects;
do $$ declare t record;
begin
  for t in select c.relname from pg_trigger g join pg_class c on c.oid=g.tgrelid
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and g.tgname='account_active_actor_guard'
  loop
    execute format('drop trigger account_active_actor_guard on public.%I',t.relname);
    if t.relname<>'profiles' then execute format('drop policy account_active_access on public.%I',t.relname); end if;
  end loop;
end $$;
alter policy profiles_select on public.profiles using(true);
alter policy profiles_update_own on public.profiles using(id=auth.uid()) with check(id=auth.uid());
drop function account_private.guard_actor();
drop function account_private.active_actor();
revoke usage on schema account_private from authenticated,service_role;
