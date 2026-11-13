-- Desfaz 20261113120300_proposal_portfolio. Recusa rodar se alguma proposta
-- tiver links ou anexos (seriam perdidos) ou se houver arquivos no bucket.
do $$
begin
  if exists (select 1 from public.proposals
             where portfolio_links <> '[]'::jsonb or attachments <> '[]'::jsonb)
     or exists (select 1 from storage.objects where bucket_id = 'proposal_attachments') then
    raise exception 'PROPOSAL_PORTFOLIO_DATA_PRESENT';
  end if;
end $$;

drop trigger if exists proposals_queue_removed_attachments on public.proposals;
create or replace function public.referenced_storage_paths(p_bucket text)
returns setof text language sql stable security definer set search_path = '' as $$
  select public.storage_path_from_url(e->>'url', p_bucket)
    from public.jobs j, jsonb_array_elements(j.attachments) e where p_bucket = 'job_attachments'
  union
  select public.storage_path_from_url(j.image_url, p_bucket)
    from public.jobs j where p_bucket = 'job_covers' and j.image_url is not null
$$;

create or replace function public.storage_cleanup_batch(
  p_limit integer default 100, p_grace interval default interval '1 day'
) returns table (bucket text, path text)
language sql stable security definer set search_path = '' as $$
  with candidates as (
    select q.bucket, q.path from public.storage_cleanup_queue q where q.attempts < 5
    union
    select o.bucket_id, o.name from storage.objects o
      where o.bucket_id in ('job_attachments', 'job_covers')
        and o.created_at < now() - p_grace
  )
  select c.bucket, c.path from candidates c
  where c.path not in (select r from public.referenced_storage_paths(c.bucket) r where r is not null)
  limit p_limit
$$;


drop function if exists public.submit_proposal(uuid, numeric, integer, text, jsonb, jsonb, jsonb);
create or replace function public.submit_proposal(
  p_job_id uuid, p_bid_amount numeric, p_estimated_days integer,
  p_cover_letter text, p_milestones jsonb default '[]'::jsonb
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

  select * into v_existing from public.proposals
  where job_id = p_job_id and freelancer_id = v_uid for update;

  if found then
    if v_existing.status = 'counter_offered' then
      raise exception 'COUNTER_OFFER_PENDING';
    end if;
    if v_existing.status <> 'pending' then
      raise exception 'PROPOSAL_ALREADY_DECIDED';
    end if;
    update public.proposals set
      bid_amount = p_bid_amount, estimated_days = p_estimated_days,
      cover_letter = coalesce(p_cover_letter, ''), proposed_milestones = v_milestones
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

  insert into public.proposals (job_id, freelancer_id, bid_amount, estimated_days, cover_letter, proposed_milestones)
  values (p_job_id, v_uid, p_bid_amount, p_estimated_days, coalesce(p_cover_letter, ''), v_milestones)
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

drop policy if exists storage_read_proposal_attachments on storage.objects;
drop function if exists public.can_read_proposal_attachment(text);
alter policy storage_insert_own_folder on storage.objects
  with check (
    bucket_id = any (array['avatars', 'portfolio', 'job_attachments', 'job_covers', 'chat_attachments', 'resumes'])
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
alter policy storage_delete_own_folder on storage.objects
  using (
    bucket_id = any (array['avatars', 'portfolio', 'job_attachments', 'job_covers', 'chat_attachments', 'resumes'])
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
delete from storage.buckets where id = 'proposal_attachments';
drop function if exists public._assert_portfolio_links(jsonb);
alter table public.proposals
  drop constraint if exists proposals_attachments_check,
  drop constraint if exists proposals_portfolio_links_check,
  drop column if exists attachments,
  drop column if exists portfolio_links;
