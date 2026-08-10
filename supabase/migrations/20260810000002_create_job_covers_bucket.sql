-- Migration: 20260810000002_create_job_covers_bucket.sql
-- Description: Criação do bucket job_covers para imagens de capa das vagas

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('job_covers', 'job_covers', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Políticas de RLS para job_covers
DROP POLICY IF EXISTS "Job Covers Public Access" ON storage.objects;
CREATE POLICY "Job Covers Public Access"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'job_covers');

DROP POLICY IF EXISTS "Job Covers Authenticated Upload" ON storage.objects;
CREATE POLICY "Job Covers Authenticated Upload"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'job_covers');

DROP POLICY IF EXISTS "Job Covers Authenticated Update" ON storage.objects;
CREATE POLICY "Job Covers Authenticated Update"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'job_covers');

DROP POLICY IF EXISTS "Job Covers Authenticated Delete" ON storage.objects;
CREATE POLICY "Job Covers Authenticated Delete"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'job_covers');
