-- ============================================================================
-- Migration: 20260804000006_create_v_job_proposals_and_chat_fixes.sql
-- Description: Cria a view v_job_proposals, habilita REPLICA IDENTITY FULL e consolida RLS de chat/propostas
-- ============================================================================

-- 1. CRIAR VIEW v_job_proposals
-- Combina dados de propostas, perfis de freelancer e detalhes da vaga.
-- Usa security_invoker = true para respeitar automaticamente as regras de RLS das tabelas base.
CREATE OR REPLACE VIEW public.v_job_proposals WITH (security_invoker = true) AS
SELECT
    p.id,
    p.job_id,
    p.freelancer_id,
    p.bid_amount,
    COALESCE(p.bid_amount, p.amount) AS amount,
    p.estimated_days,
    p.cover_letter,
    COALESCE(p.cover_letter, p.message) AS message,
    p.status,
    COALESCE(p.proposed_milestones, '[]'::jsonb) AS proposed_milestones,
    COALESCE(p.screening_answers, '[]'::jsonb) AS screening_answers,
    p.created_at,
    p.updated_at,
    COALESCE(prof.full_name, 'Freelancer') AS freelancer_name,
    prof.avatar_url AS freelancer_avatar_url,
    COALESCE(prof.rating, 5.0) AS freelancer_rating,
    COALESCE(prof.skills, '{}'::text[]) AS freelancer_skills,
    prof.bio AS freelancer_bio,
    j.title AS job_title,
    j.client_id,
    j.category AS job_category,
    j.budget_min AS job_budget_min,
    j.budget_max AS job_budget_max
FROM public.proposals p
JOIN public.jobs j ON j.id = p.job_id
LEFT JOIN public.profiles prof ON prof.id = p.freelancer_id;

-- Conceder permissões na View
GRANT SELECT ON public.v_job_proposals TO authenticated, anon, service_role;

-- 2. HABILITAR REPLICA IDENTITY FULL PARA SUPABASE REALTIME
-- Necessário para que streams e listeners do Realtime recebam o payload completo ao filtrar por colunas com RLS
ALTER TABLE public.messages REPLICA IDENTITY FULL;
ALTER TABLE public.conversations REPLICA IDENTITY FULL;
ALTER TABLE public.proposals REPLICA IDENTITY FULL;

-- 3. CONSOLIDAR POLÍTICAS DE RLS PARA CONVERSATIONS E MESSAGES
-- Garantir que participantes consigam visualizar, inserir e atualizar conversas e mensagens

-- Conversations: SELECT
DROP POLICY IF EXISTS "Conversations viewable by participants" ON public.conversations;
DROP POLICY IF EXISTS "Users can view their own conversations" ON public.conversations;
CREATE POLICY "Conversations viewable by participants"
    ON public.conversations FOR SELECT
    USING (
        auth.uid() = participant_a OR
        auth.uid() = participant_b OR
        auth.uid() = client_id OR
        auth.uid() = freelancer_id
    );

-- Conversations: INSERT
DROP POLICY IF EXISTS "Participants can create conversations" ON public.conversations;
DROP POLICY IF EXISTS "Users can insert conversations" ON public.conversations;
CREATE POLICY "Participants can create conversations"
    ON public.conversations FOR INSERT
    WITH CHECK (
        auth.uid() = participant_a OR
        auth.uid() = participant_b OR
        auth.uid() = client_id OR
        auth.uid() = freelancer_id
    );

-- Conversations: UPDATE
DROP POLICY IF EXISTS "Users can update their own conversations" ON public.conversations;
CREATE POLICY "Users can update their own conversations"
    ON public.conversations FOR UPDATE
    USING (
        auth.uid() = participant_a OR
        auth.uid() = participant_b OR
        auth.uid() = client_id OR
        auth.uid() = freelancer_id
    );

-- Messages: SELECT
DROP POLICY IF EXISTS "Messages viewable by conversation participants" ON public.messages;
DROP POLICY IF EXISTS "Users can view messages in their conversations" ON public.messages;
CREATE POLICY "Messages viewable by conversation participants"
    ON public.messages FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.conversations c
            WHERE c.id = messages.conversation_id
            AND (
                c.participant_a = auth.uid() OR
                c.participant_b = auth.uid() OR
                c.client_id = auth.uid() OR
                c.freelancer_id = auth.uid()
            )
        )
    );

-- Messages: INSERT
DROP POLICY IF EXISTS "Participants can send messages" ON public.messages;
DROP POLICY IF EXISTS "Users can insert messages" ON public.messages;
CREATE POLICY "Participants can send messages"
    ON public.messages FOR INSERT
    WITH CHECK (
        auth.uid() = sender_id AND
        EXISTS (
            SELECT 1 FROM public.conversations c
            WHERE c.id = messages.conversation_id
            AND (
                c.participant_a = auth.uid() OR
                c.participant_b = auth.uid() OR
                c.client_id = auth.uid() OR
                c.freelancer_id = auth.uid()
            )
        )
    );
