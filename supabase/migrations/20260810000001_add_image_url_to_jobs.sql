-- Migration: 20260810000001_add_image_url_to_jobs.sql
-- Description: Adiciona o campo image_url na tabela jobs para os cards visuais

ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS image_url TEXT;
