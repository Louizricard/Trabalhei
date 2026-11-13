-- Portfólio e amostras na proposta (links e anexos privados).
-- Rollback: supabase/rollbacks/20261113120300_proposal_portfolio_down.sql
--
-- O freelancer pode anexar até 10 links profissionais e 5 arquivos à
-- proposta. Os arquivos ficam no bucket privado `proposal_attachments`, no
-- caminho `<freelancer>/<vaga>/<arquivo>`, e só são lidos pelo autor e pelo
-- dono da vaga enquanto a proposta referenciar o arquivo, em qualquer status
-- da vaga ou da proposta (histórico da contratação). Ninguém mais lê.

alter table public.proposals
  add column portfolio_links jsonb not null default '[]'::jsonb,
  add column attachments jsonb not null default '[]'::jsonb,
  add constraint proposals_portfolio_links_check
    check (jsonb_typeof(portfolio_links) = 'array' and jsonb_array_length(portfolio_links) <= 10),
  add constraint proposals_attachments_check
    check (jsonb_typeof(attachments) = 'array' and jsonb_array_length(attachments) <= 5);

-- Links: até 10 URLs http(s) de até 300 caracteres, sem repetição.
create or replace function public._assert_portfolio_links(p_links jsonb)
returns void language plpgsql immutable set search_path = '' as $$
begin
  if jsonb_typeof(p_links) <> 'array' or jsonb_array_length(p_links) > 10
     or exists (select 1 from jsonb_array_elements(p_links) e
                where jsonb_typeof(e) <> 'string'
                   or (e #>> '{}') !~* '^https?://[^[:space:]/]+\.[^[:space:]]+$'
                   or char_length(e #>> '{}') > 300)
     or (select count(*) <> count(distinct lower(e #>> '{}')) from jsonb_array_elements(p_links) e) then
    raise exception 'INVALID_PORTFOLIO_LINKS';
  end if;
end;
$$;
revoke all on function public._assert_portfolio_links(jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------- Storage
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('proposal_attachments', 'proposal_attachments', false, 52428800, array[
  'application/pdf', 'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'image/png', 'image/jpeg', 'image/webp', 'application/zip', 'text/plain'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

alter policy storage_insert_own_folder on storage.objects
  with check (
    bucket_id = any (array['avatars', 'portfolio', 'job_attachments', 'job_covers', 'chat_attachments', 'resumes', 'proposal_attachments'])
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
alter policy storage_delete_own_folder on storage.objects
  using (
    bucket_id = any (array['avatars', 'portfolio', 'job_attachments', 'job_covers', 'chat_attachments', 'resumes', 'proposal_attachments'])
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- Dono da vaga lê o arquivo só se a proposta atual o referencia.
create or replace function public.can_read_proposal_attachment(p_name text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.proposals p
    join public.jobs j on j.id = p.job_id
    where p.freelancer_id::text = split_part(p_name, '/', 1)
      and p.job_id::text = split_part(p_name, '/', 2)
      and j.client_id = auth.uid()
      and exists (select 1 from jsonb_array_elements(p.attachments) e
                  where public.storage_path_from_url(e->>'url', 'proposal_attachments') = p_name)
  )
$$;
revoke all on function public.can_read_proposal_attachment(text) from public, anon;
grant execute on function public.can_read_proposal_attachment(text) to authenticated;

create policy storage_read_proposal_attachments on storage.objects
  for select to authenticated using (
    bucket_id = 'proposal_attachments'
    and ((storage.foldername(name))[1] = (select auth.uid())::text
         or public.can_read_proposal_attachment(name))
  );

-- ---------------------------------------------------------------- Envio
-- Mesma função da jornada de contratação (20261112213744), agora com links e
-- anexos. A assinatura muda, então a antiga sai para não haver ambiguidade.
drop function if exists public.submit_proposal(uuid, numeric, integer, text, jsonb);
create or replace function public.submit_proposal(
  p_job_id uuid, p_bid_amount numeric, p_estimated_days integer,
  p_cover_letter text, p_milestones jsonb default '[]'::jsonb,
  p_portfolio_links jsonb default '[]'::jsonb, p_attachments jsonb default '[]'::jsonb
)
returns public.proposals
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.platform_settings := public.settings();
  v_uid uuid := auth.uid();
  v_job public.jobs;
  v_existing public.proposals;
  v_result public.proposals;
  v_limit integer;
  v_name text;
  v_milestones jsonb := coalesce(p_milestones, '[]'::jsonb);
  v_total numeric;
  v_links jsonb := coalesce(p_portfolio_links, '[]'::jsonb);
  v_files jsonb := coalesce(p_attachments, '[]'::jsonb);
  v_has_existing boolean;
begin
  if v_uid is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not exists (select 1 from public.profiles where id = v_uid and role = 'freelancer') then
    raise exception 'ONLY_FREELANCERS_CAN_APPLY';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('submit_proposal:' || v_uid::text, 0));

  select * into v_job from public.jobs where id = p_job_id;
  if not found or v_job.status <> 'open' then raise exception 'JOB_NOT_OPEN'; end if;
  if v_job.client_id = v_uid then raise exception 'CANNOT_APPLY_TO_OWN_JOB'; end if;
  if char_length(trim(coalesce(p_cover_letter, ''))) < s.min_cover_letter_chars then
    raise exception 'COVER_LETTER_TOO_SHORT';
  end if;
  v_total := public._proposed_milestones_total(v_milestones);
  if v_total is null or (jsonb_array_length(v_milestones) > 0 and v_total <> p_bid_amount) then
    raise exception 'INVALID_MILESTONES';
  end if;

  perform public._assert_portfolio_links(v_links);
  if exists (select 1 from jsonb_array_elements(case jsonb_typeof(v_files) when 'array' then v_files else '[]' end) e
             where split_part(public.storage_path_from_url(e->>'url', 'proposal_attachments'), '/', 2)
                   is distinct from p_job_id::text) then
    raise exception 'ATTACHMENT_INVALID';
  end if;

  select * into v_existing from public.proposals
  where job_id = p_job_id and freelancer_id = v_uid for update;
  v_has_existing := found;
  perform public.assert_attachment_refs(
    v_files, case when v_has_existing then v_existing.attachments else '[]'::jsonb end,
    'proposal_attachments', 5);

  if v_has_existing then
    if v_existing.status = 'counter_offered' then
      raise exception 'COUNTER_OFFER_PENDING';
    end if;
    if v_existing.status <> 'pending' then
      raise exception 'PROPOSAL_ALREADY_DECIDED';
    end if;
    update public.proposals set
      bid_amount = p_bid_amount, estimated_days = p_estimated_days,
      cover_letter = coalesce(p_cover_letter, ''), proposed_milestones = v_milestones,
      portfolio_links = v_links, attachments = v_files
    where id = v_existing.id returning * into v_result;
    return v_result;
  end if;

  -- Envio em massa: teto por 24 h vale para todos os planos.
  if (select count(*) from public.proposals
      where freelancer_id = v_uid and created_at > now() - interval '24 hours') >= s.daily_proposals then
    raise exception 'DAILY_PROPOSAL_LIMIT';
  end if;

  v_limit := case when public.is_pro(v_uid) then s.pro_monthly_proposals else s.free_monthly_proposals end;
  if public.counted_proposals(v_uid, date_trunc('month', now())) >= v_limit then
    raise exception 'PROPOSAL_QUOTA_EXCEEDED';
  end if;

  insert into public.proposals (job_id, freelancer_id, bid_amount, estimated_days, cover_letter,
    proposed_milestones, portfolio_links, attachments)
  values (p_job_id, v_uid, p_bid_amount, p_estimated_days, coalesce(p_cover_letter, ''),
    v_milestones, v_links, v_files)
  returning * into v_result;

  select full_name into v_name from public.profiles where id = v_uid;
  perform public.notify(
    v_job.client_id, 'proposal_received', 'Nova proposta recebida',
    coalesce(v_name, 'Um freelancer') || ' enviou uma proposta para "' || v_job.title || '".',
    jsonb_build_object('job_id', v_job.id, 'proposal_id', v_result.id,
                       'route', '/jobs/' || v_job.id || '/proposals')
  );
  return v_result;
end;
$$;
revoke all on function public.submit_proposal(uuid, numeric, integer, text, jsonb, jsonb, jsonb) from public, anon;
grant execute on function public.submit_proposal(uuid, numeric, integer, text, jsonb, jsonb, jsonb) to authenticated;

-- ---------------------------------------------------------------- Limpeza
create trigger proposals_queue_removed_attachments
  after update of attachments or delete on public.proposals
  for each row execute function public.queue_removed_attachments('attachments', 'proposal_attachments');

create or replace function public.referenced_storage_paths(p_bucket text)
returns setof text language sql stable security definer set search_path = '' as $$
  select public.storage_path_from_url(e->>'url', p_bucket)
    from public.jobs j, jsonb_array_elements(j.attachments) e where p_bucket = 'job_attachments'
  union
  select public.storage_path_from_url(j.image_url, p_bucket)
    from public.jobs j where p_bucket = 'job_covers' and j.image_url is not null
  union
  select public.storage_path_from_url(e->>'url', p_bucket)
    from public.proposals p, jsonb_array_elements(p.attachments) e where p_bucket = 'proposal_attachments'
$$;

create or replace function public.storage_cleanup_batch(
  p_limit integer default 100, p_grace interval default interval '1 day'
) returns table (bucket text, path text)
language sql stable security definer set search_path = '' as $$
  with candidates as (
    select q.bucket, q.path from public.storage_cleanup_queue q where q.attempts < 5
    union
    select o.bucket_id, o.name from storage.objects o
      where o.bucket_id in ('job_attachments', 'job_covers', 'proposal_attachments')
        and o.created_at < now() - p_grace
  )
  select c.bucket, c.path from candidates c
  where c.path not in (select r from public.referenced_storage_paths(c.bucket) r where r is not null)
  limit p_limit
$$;

