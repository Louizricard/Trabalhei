-- Migration: 20260806000002_phase3_workflow_completion_down.sql
-- Description: Rollback da FASE 3
-- Down Migration

DROP TRIGGER IF EXISTS trg_dispute_opened ON public.disputes;
DROP FUNCTION IF EXISTS public.handle_dispute_opened_trigger();

DROP TABLE IF EXISTS public.proposal_counter_offers CASCADE;
DROP TABLE IF EXISTS public.dispute_events CASCADE;
DROP TABLE IF EXISTS public.milestone_revisions CASCADE;

ALTER TABLE public.disputes DROP COLUMN IF EXISTS description;
ALTER TABLE public.disputes DROP COLUMN IF EXISTS disputed_amount;
ALTER TABLE public.disputes DROP COLUMN IF EXISTS evidence_attachments;
ALTER TABLE public.disputes DROP COLUMN IF EXISTS updated_at;

ALTER TABLE public.milestones DROP COLUMN IF EXISTS deliverable_notes;
ALTER TABLE public.milestones DROP COLUMN IF EXISTS deliverable_attachments;
ALTER TABLE public.milestones DROP COLUMN IF EXISTS submitted_at;
ALTER TABLE public.milestones DROP COLUMN IF EXISTS revision_count;

ALTER TABLE public.messages DROP COLUMN IF EXISTS attachment_name;
ALTER TABLE public.messages DROP COLUMN IF EXISTS attachment_size;
ALTER TABLE public.messages DROP COLUMN IF EXISTS attachment_mime;

ALTER TABLE public.jobs DROP COLUMN IF EXISTS attachments;
