-- Desfaz 20261120145624_attachment_mime_allowlist: volta a aceitar qualquer tipo.
update storage.buckets set allowed_mime_types = null
where id in ('chat_attachments', 'job_attachments');
