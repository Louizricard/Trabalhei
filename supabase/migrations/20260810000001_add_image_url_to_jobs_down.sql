-- Migration: 20260810000001_add_image_url_to_jobs_down.sql
-- Description: Rollback do campo image_url na tabela jobs

ALTER TABLE public.jobs DROP COLUMN IF EXISTS image_url;
