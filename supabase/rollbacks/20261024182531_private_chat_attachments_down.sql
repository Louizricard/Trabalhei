-- Rollback: chat_attachments volta a ser público.
drop policy if exists "storage_read_chat_attachments" on storage.objects;
drop policy if exists "storage_read_public_buckets" on storage.objects;
create policy "storage_read_public_buckets" on storage.objects
  for select using (bucket_id in ('avatars', 'portfolio', 'job_attachments', 'job_covers', 'chat_attachments'));
update storage.buckets set public = true where id = 'chat_attachments';
