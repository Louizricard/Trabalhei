-- Migration: 20260810000002_create_job_covers_bucket_down.sql

DROP POLICY IF EXISTS "Job Covers Authenticated Delete" ON storage.objects;
DROP POLICY IF EXISTS "Job Covers Authenticated Update" ON storage.objects;
DROP POLICY IF EXISTS "Job Covers Authenticated Upload" ON storage.objects;
DROP POLICY IF EXISTS "Job Covers Public Access" ON storage.objects;

DELETE FROM storage.buckets WHERE id = 'job_covers';
