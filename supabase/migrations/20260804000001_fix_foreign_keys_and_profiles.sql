-- ============================================================================
-- Migration: 20260804000001_fix_foreign_keys_and_profiles.sql
-- Description: Fix foreign keys on jobs, proposals, conversations, and messages to point to unified profiles table
-- ============================================================================

-- 1. Fix jobs table foreign key
ALTER TABLE IF EXISTS public.jobs 
    DROP CONSTRAINT IF EXISTS jobs_client_id_fkey;

ALTER TABLE public.jobs 
    ADD CONSTRAINT jobs_client_id_fkey 
    FOREIGN KEY (client_id) 
    REFERENCES public.profiles(id) 
    ON DELETE CASCADE;

-- 2. Fix proposals table foreign key
ALTER TABLE IF EXISTS public.proposals 
    DROP CONSTRAINT IF EXISTS proposals_freelancer_id_fkey;

ALTER TABLE public.proposals 
    ADD CONSTRAINT proposals_freelancer_id_fkey 
    FOREIGN KEY (freelancer_id) 
    REFERENCES public.profiles(id) 
    ON DELETE CASCADE;

-- 3. Fix conversations table foreign keys
ALTER TABLE IF EXISTS public.conversations 
    DROP CONSTRAINT IF EXISTS conversations_client_id_fkey,
    DROP CONSTRAINT IF EXISTS conversations_freelancer_id_fkey,
    DROP CONSTRAINT IF EXISTS conversations_participant_a_fkey,
    DROP CONSTRAINT IF EXISTS conversations_participant_b_fkey;

ALTER TABLE public.conversations 
    ADD CONSTRAINT conversations_participant_a_fkey 
    FOREIGN KEY (participant_a) 
    REFERENCES public.profiles(id) 
    ON DELETE CASCADE;

ALTER TABLE public.conversations 
    ADD CONSTRAINT conversations_participant_b_fkey 
    FOREIGN KEY (participant_b) 
    REFERENCES public.profiles(id) 
    ON DELETE CASCADE;

-- 4. Fix messages table sender_id foreign key
ALTER TABLE IF EXISTS public.messages 
    DROP CONSTRAINT IF EXISTS messages_sender_id_fkey;

ALTER TABLE public.messages 
    ADD CONSTRAINT messages_sender_id_fkey 
    FOREIGN KEY (sender_id) 
    REFERENCES public.profiles(id) 
    ON DELETE CASCADE;

-- 5. Notify PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';
