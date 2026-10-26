-- Visitantes sem conta exploram o app: mural de vagas abertas, detalhes da
-- vaga e perfis públicos. As colunas visíveis continuam as mesmas liberadas
-- por coluna para anon e authenticated; nada privado (e-mail, conversas,
-- propostas, contratos) passa a ser lido sem login.
create policy jobs_select_anon on public.jobs
  for select to anon
  using (status = 'open');

create policy profiles_select_anon on public.profiles
  for select to anon
  using (deleted_at is null);

create policy portfolio_select_anon on public.portfolio_items
  for select to anon
  using (true);

create policy reviews_select_anon on public.reviews
  for select to anon
  using (true);

-- Total de propostas da vaga, como campo calculado do PostgREST
-- (`select=*,proposals_count`). O embed `proposals(count)` passa pela RLS de
-- proposals e só contava as propostas do próprio usuário.
create function public.proposals_count(job public.jobs)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer from public.proposals p where p.job_id = job.id
$$;

revoke all on function public.proposals_count(public.jobs) from public;
grant execute on function public.proposals_count(public.jobs) to anon, authenticated;
