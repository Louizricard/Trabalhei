-- Restringe os tipos de arquivo aceitos em `chat_attachments` e `job_attachments`
-- aos mesmos que o app oferece (attachment_rules.dart, chat e fotos).
-- Sem a lista, a API aceitava qualquer Content-Type; um HTML ou SVG enviado
-- direto pela API ficaria hospedado no bucket público de anexos de vaga.
-- Vale só para novos envios; arquivos existentes não mudam.
-- Rollback: supabase/rollbacks/20261120145624_attachment_mime_allowlist_down.sql

update storage.buckets
set allowed_mime_types = array[
  'application/pdf', 'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'image/png', 'image/jpeg', 'image/webp', 'image/gif',
  'application/zip', 'text/plain']
where id in ('chat_attachments', 'job_attachments');
