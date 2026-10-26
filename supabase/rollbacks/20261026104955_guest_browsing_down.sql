-- Desfaz 20261026104955_guest_browsing. Antes, volte o app para o embed
-- `proposals(count)`: sem a função, `select=*,proposals_count` falha.
drop function if exists public.proposals_count(public.jobs);

drop policy if exists reviews_select_anon on public.reviews;
drop policy if exists portfolio_select_anon on public.portfolio_items;
drop policy if exists profiles_select_anon on public.profiles;
drop policy if exists jobs_select_anon on public.jobs;
