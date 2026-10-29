do $$ begin
  if exists(select 1 from public.account_deletion_requests) then raise exception 'ACCOUNT_DELETION_DATA_PRESENT'; end if;
end $$;
drop function public.complete_account_deletion(uuid,uuid);
drop function public.fail_account_deletion(uuid,uuid,text);
drop function account_private.deletion_request(uuid,uuid);
drop function public.begin_account_deletion(uuid);
drop function account_private.redact_profile(uuid);
drop table public.account_deletion_requests;
drop schema account_private;
