-- ============================================================================
-- Exclusão de conta pelo próprio usuário (LGPD, art. 18, VI).
--
-- Fluxo (Edge Function `delete-account`):
--   1. Recusa se houver contrato em andamento (status 'active').
--   2. Cancela a assinatura Pro no Asaas, se houver.
--   3. Chama delete_account_data(user):
--      * sem histórico de contratos -> retorna true e a função apaga o
--        auth.users; o ON DELETE CASCADE remove perfil, vagas, propostas,
--        conversas, notificações etc.
--      * com histórico de contratos -> os contratos, marcos, mensagens e
--        avaliações são mantidos para a outra parte (exercício regular de
--        direitos, LGPD art. 16, II); o perfil é anonimizado, os dados
--        acessórios são apagados e retorna false. A função então faz soft
--        delete do auth.users (e-mail e identidades são descartados pelo Auth).
--   4. Remove os arquivos do usuário no Storage.
-- ============================================================================

alter table public.profiles add column deleted_at timestamptz;

-- A busca de freelancers filtra por papel e ignora contas excluídas.
create index profiles_active_role_idx on public.profiles (role) where deleted_at is null;

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

-- Só a Edge Function (service_role) chama esta função.
revoke execute on function public.delete_account_data(uuid) from public, anon, authenticated;
grant execute on function public.delete_account_data(uuid) to service_role;
