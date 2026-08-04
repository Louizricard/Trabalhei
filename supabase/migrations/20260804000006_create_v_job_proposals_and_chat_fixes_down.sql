-- ============================================================================
-- Migration: 20260804000006_create_v_job_proposals_and_chat_fixes_down.sql
-- Description: Rollback da view v_job_proposals
-- ============================================================================

DROP VIEW IF EXISTS public.v_job_proposals CASCADE;
