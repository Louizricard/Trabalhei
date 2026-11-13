-- Desfaz 20261113185435_plan_upload_limits. Não apaga dados: só remove as
-- validações e devolve o teto anterior (20 MB) aos buckets.
drop trigger if exists jobs_attachment_refs on public.jobs;
drop trigger if exists milestones_attachment_refs on public.milestones;
drop trigger if exists milestone_revisions_attachment_refs on public.milestone_revisions;
drop trigger if exists messages_attachment_ref on public.messages;
drop function if exists public.enforce_message_attachment();
drop function if exists public.enforce_attachment_refs();
drop function if exists public.assert_attachment_refs(jsonb, jsonb, text, integer);
drop function if exists public.storage_path_from_url(text, text);
drop function if exists public.upload_limit_bytes(uuid);
update storage.buckets set file_size_limit = 20971520
  where id in ('job_attachments', 'chat_attachments');
