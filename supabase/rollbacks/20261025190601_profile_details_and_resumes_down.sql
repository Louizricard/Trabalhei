-- Desfaz 20261025190601_profile_details_and_resumes. Apague antes os arquivos
-- do bucket "resumes" (o Storage não remove um bucket com objetos).
update storage.buckets set allowed_mime_types = null where id in ('avatars', 'portfolio');

alter policy storage_delete_own_folder on storage.objects
  using (
    bucket_id = any (array['avatars', 'portfolio', 'job_attachments', 'job_covers', 'chat_attachments'])
    and (storage.foldername(name))[1] = (auth.uid())::text
  );

alter policy storage_insert_own_folder on storage.objects
  with check (
    bucket_id = any (array['avatars', 'portfolio', 'job_attachments', 'job_covers', 'chat_attachments'])
    and (storage.foldername(name))[1] = (auth.uid())::text
  );

drop policy if exists storage_read_resumes on storage.objects;
delete from storage.buckets where id = 'resumes';

alter table public.profiles
  drop constraint if exists profiles_links_check,
  drop constraint if exists profiles_location_check,
  drop constraint if exists profiles_headline_check,
  drop column if exists resume_url,
  drop column if exists github_url,
  drop column if exists linkedin_url,
  drop column if exists website_url,
  drop column if exists location,
  drop column if exists headline;
