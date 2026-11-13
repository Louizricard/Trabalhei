-- Categorias generalistas em dois níveis: área + subcategoria.
-- Rollback: supabase/rollbacks/20261113120100_generalist_categories_down.sql
--
-- Antes, jobs.category era texto livre só de tecnologia (Mobile, Frontend,
-- Backend, Fullstack, DevOps, Design). Agora a categoria é uma área do
-- catálogo (freelanceflow/lib/core/config/work_categories.dart) e a
-- especialização fica, de forma permanente, em `subcategory`. Nenhum valor
-- antigo se perde: "Mobile" vira área "Tecnologia" + subcategoria "Mobile";
-- valores desconhecidos vão para "Outros" com o valor original na
-- subcategoria.

create or replace function public.work_areas()
returns text[] language sql immutable set search_path = '' as $$
  select array['Tecnologia', 'Design', 'Marketing', 'Redação e Conteúdo', 'Tradução',
    'Audiovisual e Foto', 'Administração e Assistência', 'Vendas e Comercial',
    'Finanças e Jurídico', 'Educação', 'Engenharia e Arquitetura', 'Outros']
$$;

-- Subcategoria vazia vale para qualquer área; "Outros" aceita texto livre
-- (guarda categorias antigas fora do catálogo).
create or replace function public.is_valid_subcategory(p_area text, p_subcategory text)
returns boolean language sql immutable set search_path = '' as $$
  select p_subcategory is null or case p_area
    when 'Tecnologia' then p_subcategory = any (array['Frontend', 'Backend', 'Fullstack',
      'Mobile', 'DevOps', 'Dados e IA', 'WordPress e e-commerce', 'Suporte de TI', 'Testes e QA'])
    when 'Design' then p_subcategory = any (array['UI/UX', 'Identidade visual',
      'Design gráfico', 'Ilustração', 'Apresentações', '3D e modelagem'])
    when 'Marketing' then p_subcategory = any (array['Social media', 'Tráfego pago', 'SEO',
      'E-mail marketing', 'Estratégia e branding'])
    when 'Redação e Conteúdo' then p_subcategory = any (array['Copywriting', 'Artigos e blog',
      'Roteiros', 'Revisão de texto', 'Conteúdo para redes'])
    when 'Tradução' then p_subcategory = any (array['Inglês', 'Espanhol', 'Outros idiomas',
      'Legendagem', 'Transcrição'])
    when 'Audiovisual e Foto' then p_subcategory = any (array['Edição de vídeo',
      'Motion design', 'Fotografia', 'Edição de foto', 'Áudio e locução'])
    when 'Administração e Assistência' then p_subcategory = any (array['Assistente virtual',
      'Digitação e dados', 'Atendimento ao cliente', 'Gestão de projetos', 'Recursos humanos'])
    when 'Vendas e Comercial' then p_subcategory = any (array['Prospecção', 'Pré-vendas',
      'Gestão de CRM'])
    when 'Finanças e Jurídico' then p_subcategory = any (array['Contabilidade',
      'Consultoria financeira', 'Assessoria jurídica'])
    when 'Educação' then p_subcategory = any (array['Aulas particulares', 'Idiomas',
      'Cursos e treinamentos', 'Mentoria'])
    when 'Engenharia e Arquitetura' then p_subcategory = any (array['Projetos arquitetônicos',
      'Design de interiores', 'Engenharia civil', 'Engenharia elétrica'])
    when 'Outros' then char_length(p_subcategory) <= 60
    else false
  end
$$;

-- Converte um valor antigo de categoria em (área, subcategoria).
create or replace function public.legacy_category(p_value text, out area text, out subcategory text)
language sql immutable set search_path = '' as $$
  select
    case
      when lower(p_value) in ('mobile', 'frontend', 'backend', 'fullstack', 'devops') then 'Tecnologia'
      when lower(p_value) = any (select lower(a) from unnest(public.work_areas()) a)
        then (select a from unnest(public.work_areas()) a where lower(a) = lower(p_value))
      else 'Outros'
    end,
    case
      when lower(p_value) in ('mobile', 'frontend', 'backend', 'fullstack', 'devops')
        then (select s from unnest(array['Mobile', 'Frontend', 'Backend', 'Fullstack', 'DevOps']) s
              where lower(s) = lower(p_value))
      when lower(p_value) = any (select lower(a) from unnest(public.work_areas()) a) then null
      else nullif(left(trim(p_value), 60), '')
    end
$$;

-- --------------------------------------------------------------- jobs
alter table public.jobs add column subcategory text;
update public.jobs set (category, subcategory) =
  (select l.area, l.subcategory from public.legacy_category(category) l);
alter table public.jobs
  add constraint jobs_category_area check (category = any (public.work_areas())),
  add constraint jobs_subcategory_valid check (public.is_valid_subcategory(category, subcategory));
create index jobs_subcategory_idx on public.jobs (category, subcategory);
grant insert (subcategory), update (subcategory) on public.jobs to authenticated;

-- --------------------------------------------------------------- alertas
alter table public.job_alerts add column subcategory text;
update public.job_alerts set (category, subcategory) =
  (select l.area, l.subcategory from public.legacy_category(category) l)
  where category is not null;
alter table public.job_alerts
  add constraint job_alerts_category_area
    check (category is null or category = any (public.work_areas())),
  add constraint job_alerts_subcategory_valid
    check (subcategory is null or (category is not null
      and public.is_valid_subcategory(category, subcategory)));

-- Alerta por área casa com qualquer subcategoria; com subcategoria, só ela.
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
    and (a.subcategory is null or lower(j.subcategory) = lower(a.subcategory))
    and (a.experience_level is null or j.experience_level in (a.experience_level, 'all'))
    and (a.contract_type is null or j.contract_type = a.contract_type)
    and (a.min_budget is null or j.budget_max >= a.min_budget)
    and (a.max_deadline_days is null or j.deadline_days <= a.max_deadline_days)
    and (not a.urgent_only or j.is_urgent)
$$;

-- --------------------------------------------------------------- perfis
-- Área de atuação do freelancer (opcional), usada na busca de talentos.
alter table public.profiles
  add column category text,
  add column subcategory text,
  add constraint profiles_category_area
    check (category is null or category = any (public.work_areas())),
  add constraint profiles_subcategory_valid
    check (subcategory is null or (category is not null
      and public.is_valid_subcategory(category, subcategory)));
create index profiles_category_idx on public.profiles (category) where category is not null;
grant select (category, subcategory) on public.profiles to anon, authenticated;
grant update (category, subcategory) on public.profiles to authenticated;
