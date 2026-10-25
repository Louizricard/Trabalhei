-- Perfil mais completo: título profissional, cidade, links e currículo (PDF).
alter table public.profiles
  add column headline text,
  add column location text,
  add column website_url text,
  add column linkedin_url text,
  add column github_url text,
  add column resume_url text;

alter table public.profiles
  add constraint profiles_headline_check
    check (headline is null or char_length(headline) <= 80),
  add constraint profiles_location_check
    check (location is null or char_length(location) <= 80),
  add constraint profiles_links_check check (
    (website_url is null or (website_url ~* '^https?://' and char_length(website_url) <= 300))
    and (linkedin_url is null or (linkedin_url ~* '^https?://' and char_length(linkedin_url) <= 300))
    and (github_url is null or (github_url ~* '^https?://' and char_length(github_url) <= 300))
    and (resume_url is null or char_length(resume_url) <= 500)
  );

-- Mesmo modelo das demais colunas: leitura pública (para usuários logados,
-- pela policy) e edição só das colunas do próprio perfil.
grant select (headline, location, website_url, linkedin_url, github_url, resume_url)
  on public.profiles to anon, authenticated;
grant update (headline, location, website_url, linkedin_url, github_url, resume_url)
  on public.profiles to authenticated;

-- Currículos: só PDF, até 5 MB, visíveis apenas a usuários logados.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('resumes', 'resumes', false, 5242880, array['application/pdf'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create policy storage_read_resumes on storage.objects
  for select to authenticated
  using (bucket_id = 'resumes');

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

-- Fotos de perfil e imagens de portfólio: só imagens (capas já eram assim).
update storage.buckets
  set allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
  where id in ('avatars', 'portfolio');
