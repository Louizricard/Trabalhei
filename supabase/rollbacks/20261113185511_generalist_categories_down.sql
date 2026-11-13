-- Desfaz 20261113185511_generalist_categories.
-- Volta a categoria antiga (texto livre) a partir da subcategoria quando ela
-- veio do remapeamento (Tecnologia + Mobile/Frontend/Backend/Fullstack/DevOps,
-- ou Outros + valor antigo). Recusa rodar se houver dado que não cabe no
-- modelo antigo, para não perder informação: subcategorias novas, área de
-- perfil preenchida.
do $$
begin
  if exists (select 1 from public.jobs
             where subcategory is not null
               and not (category = 'Tecnologia' and subcategory in ('Mobile', 'Frontend', 'Backend', 'Fullstack', 'DevOps'))
               and category <> 'Outros')
     or exists (select 1 from public.profiles where category is not null)
     or exists (select 1 from public.job_alerts
                where subcategory is not null
                  and not (category = 'Tecnologia' and subcategory in ('Mobile', 'Frontend', 'Backend', 'Fullstack', 'DevOps'))
                  and category <> 'Outros') then
    raise exception 'CATEGORY_DATA_PRESENT';
  end if;
end $$;

drop index if exists public.profiles_category_idx;
alter table public.profiles
  drop constraint if exists profiles_subcategory_valid,
  drop constraint if exists profiles_category_area,
  drop column if exists subcategory,
  drop column if exists category;

create or replace function public.job_matches_alert(j public.jobs, a public.job_alerts)
returns boolean
language sql
stable
set search_path = ''
as $$
  select
    (a.query is null or trim(a.query) = ''
      or j.title ilike '%' || trim(a.query) || '%'
      or j.description ilike '%' || trim(a.query) || '%'
      or exists (select 1 from unnest(j.skills_required) s where s ilike '%' || trim(a.query) || '%'))
    and (a.category is null or lower(j.category) = lower(a.category))
    and (a.experience_level is null or j.experience_level in (a.experience_level, 'all'))
    and (a.contract_type is null or j.contract_type = a.contract_type)
    and (a.min_budget is null or j.budget_max >= a.min_budget)
    and (a.max_deadline_days is null or j.deadline_days <= a.max_deadline_days)
    and (not a.urgent_only or j.is_urgent)
$$;
alter table public.job_alerts
  drop constraint if exists job_alerts_subcategory_valid,
  drop constraint if exists job_alerts_category_area;
update public.job_alerts set category = subcategory where subcategory is not null;
alter table public.job_alerts drop column if exists subcategory;

alter table public.jobs
  drop constraint if exists jobs_subcategory_valid,
  drop constraint if exists jobs_category_area;
update public.jobs set category = subcategory where subcategory is not null;
drop index if exists public.jobs_subcategory_idx;
alter table public.jobs drop column if exists subcategory;

drop function if exists public.legacy_category(text);
drop function if exists public.is_valid_subcategory(text, text);
drop function if exists public.work_areas();
