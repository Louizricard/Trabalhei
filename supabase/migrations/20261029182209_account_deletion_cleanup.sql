create or replace function public.delete_account_data(p_user uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_hard boolean;
begin
  perform 1 from public.profiles where id=p_user for update;
  if not found then raise exception 'PROFILE_NOT_FOUND'; end if;
  if exists(select 1 from public.contracts where status='active' and p_user in(client_id,freelancer_id))
    then raise exception 'ACTIVE_CONTRACTS'; end if;
  v_hard:=not exists(select 1 from public.contracts where p_user in(client_id,freelancer_id));
  update public.proposals set status='rejected' where status in('pending','counter_offered')
    and job_id in(select id from public.jobs where client_id=p_user and status='open');
  update public.jobs set status='cancelled' where client_id=p_user and status='open';
  delete from public.proposals p where p.freelancer_id=p_user
    and not exists(select 1 from public.contracts c where c.proposal_id=p.id);
  delete from public.portfolio_items where freelancer_id=p_user;
  delete from public.notifications where user_id=p_user;
  delete from public.billing_customers where user_id=p_user;
  delete from public.push_subscriptions where user_id=p_user;
  delete from public.notification_settings where user_id=p_user;
  delete from public.job_alerts where user_id=p_user;
  delete from public.proposal_templates where user_id=p_user;
  delete from public.client_notes where freelancer_id=p_user;
  delete from public.admins where user_id=p_user;
  perform account_private.redact_profile(p_user);
  return v_hard;
end;
$$;
revoke all on function public.delete_account_data(uuid) from public,anon,authenticated;
grant execute on function public.delete_account_data(uuid) to service_role;

-- Pedidos antigos já autorizavam anonimização. Não restaura PII no rollback.
update public.profiles set headline=null,location=null,website_url=null,
  linkedin_url=null,github_url=null,resume_url=null where deleted_at is not null;
