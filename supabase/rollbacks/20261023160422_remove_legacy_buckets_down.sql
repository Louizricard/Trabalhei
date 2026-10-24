-- Rollback: recria os buckets legados vazios, com os limites originais.
insert into storage.buckets (id, name, public, file_size_limit)
values
  ('deliverables', 'deliverables', true, 104857600),
  ('dispute_attachments', 'dispute_attachments', true, 52428800)
on conflict (id) do nothing;
