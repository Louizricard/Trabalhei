do $$ begin
  if exists(select 1 from public.account_deletion_requests) then raise exception 'ACCOUNT_DELETION_DATA_PRESENT'; end if;
end $$;
create or replace function public.delete_account_data(p_user uuid)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from public.contracts
             where status = 'active' and (client_id = p_user or freelancer_id = p_user)) then
    raise exception 'ACTIVE_CONTRACTS';
  end if;

  if not exists (select 1 from public.contracts
                 where client_id = p_user or freelancer_id = p_user) then
    return true;
  end if;

  -- Vagas abertas são encerradas e as propostas pendentes recebidas, recusadas.
  update public.proposals set status = 'rejected'
  where status in ('pending', 'counter_offered')
    and job_id in (select id from public.jobs where client_id = p_user and status = 'open');
  update public.jobs set status = 'cancelled' where client_id = p_user and status = 'open';

  -- Propostas enviadas que não viraram contrato.
  delete from public.proposals p
  where p.freelancer_id = p_user
    and not exists (select 1 from public.contracts c where c.proposal_id = p.id);

  delete from public.portfolio_items where freelancer_id = p_user;
  delete from public.notifications where user_id = p_user;
  delete from public.billing_customers where user_id = p_user;

  update public.profiles set
    full_name = 'Usuário removido',
    avatar_url = null,
    company_name = null,
    bio = null,
    hourly_rate = 0,
    skills = '{}',
    availability_status = 'unavailable',
    plan = 'free',
    plan_expires_at = null,
    deleted_at = now()
  where id = p_user;

  return false;
end;
$$;
