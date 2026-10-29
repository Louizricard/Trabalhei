do $$ begin
  if exists(select 1 from public.account_deletion_requests) then raise exception 'ACCOUNT_DELETION_DATA_PRESENT'; end if;
end $$;
drop function public.prepare_account_auth_deletion(uuid,uuid);
drop function public.account_deletion_objects(uuid,uuid);
