-- Migration: 20260806000002_phase3_workflow_completion.sql
-- Description: FASE 3 — Anexos em Vagas e Chat, Revisão de Entregas, Sistema Completo de Disputas e Contrapropostas
-- Up Migration

-- ============================================================================
-- 1. STORAGE BUCKETS & POLICIES
-- ============================================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('job_attachments', 'job_attachments', true, 15728640, ARRAY[
    'image/jpeg', 'image/png', 'image/webp', 'image/gif',
    'application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/zip', 'text/plain'
  ]),
  ('chat_attachments', 'chat_attachments', true, 20971520, ARRAY[
    'image/jpeg', 'image/png', 'image/webp', 'image/gif',
    'application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/zip', 'text/plain'
  ]),
  ('dispute_attachments', 'dispute_attachments', true, 20971520, ARRAY[
    'image/jpeg', 'image/png', 'image/webp', 'image/gif',
    'application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/zip', 'text/plain'
  ])
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Políticas de RLS para Storage Objects (Job, Chat e Dispute Attachments)
DROP POLICY IF EXISTS "Public Read Job Attachments" ON storage.objects;
CREATE POLICY "Public Read Job Attachments"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'job_attachments');

DROP POLICY IF EXISTS "Authenticated Upload Job Attachments" ON storage.objects;
CREATE POLICY "Authenticated Upload Job Attachments"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'job_attachments');

DROP POLICY IF EXISTS "Public Read Chat Attachments" ON storage.objects;
CREATE POLICY "Public Read Chat Attachments"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'chat_attachments');

DROP POLICY IF EXISTS "Authenticated Upload Chat Attachments" ON storage.objects;
CREATE POLICY "Authenticated Upload Chat Attachments"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'chat_attachments');

DROP POLICY IF EXISTS "Public Read Dispute Attachments" ON storage.objects;
CREATE POLICY "Public Read Dispute Attachments"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'dispute_attachments');

DROP POLICY IF EXISTS "Authenticated Upload Dispute Attachments" ON storage.objects;
CREATE POLICY "Authenticated Upload Dispute Attachments"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'dispute_attachments');

-- ============================================================================
-- 2. JOBS ATTACHMENTS
-- ============================================================================
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS attachments JSONB DEFAULT '[]'::jsonb;
COMMENT ON COLUMN public.jobs.attachments IS 'Array of file metadata objects: {id, name, url, size, mime_type}';

-- ============================================================================
-- 3. CHAT MESSAGE ATTACHMENTS
-- ============================================================================
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS attachment_name TEXT;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS attachment_size INT;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS attachment_mime TEXT;

ALTER TABLE public.messages DROP CONSTRAINT IF EXISTS messages_message_type_check;
ALTER TABLE public.messages ADD CONSTRAINT messages_message_type_check
  CHECK (message_type IN ('text', 'system_event', 'milestone_update', 'file', 'image', 'document'));

-- ============================================================================
-- 4. MILESTONES & MILESTONE REVISIONS
-- ============================================================================
ALTER TABLE public.milestones DROP CONSTRAINT IF EXISTS milestones_status_check;
ALTER TABLE public.milestones ADD CONSTRAINT milestones_status_check
  CHECK (status IN ('pending', 'funded_in_escrow', 'submitted', 'approved_and_released', 'disputed', 'in_revision'));

ALTER TABLE public.milestones ADD COLUMN IF NOT EXISTS deliverable_notes TEXT;
ALTER TABLE public.milestones ADD COLUMN IF NOT EXISTS deliverable_attachments JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.milestones ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMPTZ;
ALTER TABLE public.milestones ADD COLUMN IF NOT EXISTS revision_count INT DEFAULT 0;

CREATE TABLE IF NOT EXISTS public.milestone_revisions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    milestone_id UUID NOT NULL REFERENCES public.milestones(id) ON DELETE CASCADE,
    contract_id UUID NOT NULL REFERENCES public.contracts(id) ON DELETE CASCADE,
    requested_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    comment TEXT NOT NULL,
    attachments JSONB DEFAULT '[]'::jsonb,
    status TEXT NOT NULL CHECK (status IN ('open', 'resolved')) DEFAULT 'open',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.milestone_revisions IS 'Histórico completo de revisões solicitadas pelos clientes para cada entrega de marco';

CREATE INDEX IF NOT EXISTS idx_milestone_revisions_milestone ON public.milestone_revisions(milestone_id);
CREATE INDEX IF NOT EXISTS idx_milestone_revisions_contract ON public.milestone_revisions(contract_id);

ALTER TABLE public.milestone_revisions ENABLE ROW LEVEL SECURITY;

-- RLS: participantes do contrato podem visualizar revisões
DROP POLICY IF EXISTS "Participants can view milestone revisions" ON public.milestone_revisions;
CREATE POLICY "Participants can view milestone revisions"
    ON public.milestone_revisions
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.contracts c
            WHERE c.id = milestone_revisions.contract_id
            AND (c.client_id = auth.uid() OR c.freelancer_id = auth.uid())
        )
    );

-- RLS: clientes podem solicitar revisões
DROP POLICY IF EXISTS "Clients can insert milestone revisions" ON public.milestone_revisions;
CREATE POLICY "Clients can insert milestone revisions"
    ON public.milestone_revisions
    FOR INSERT
    WITH CHECK (
        auth.uid() = requested_by AND
        EXISTS (
            SELECT 1 FROM public.contracts c
            WHERE c.id = milestone_revisions.contract_id
            AND c.client_id = auth.uid()
        )
    );

-- ============================================================================
-- 5. DISPUTES & DISPUTE EVENTS (TIMELINE DE MEDIAÇÃO)
-- ============================================================================
ALTER TABLE public.disputes ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.disputes ADD COLUMN IF NOT EXISTS disputed_amount NUMERIC(10,2);
ALTER TABLE public.disputes ADD COLUMN IF NOT EXISTS evidence_attachments JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.disputes ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

CREATE TABLE IF NOT EXISTS public.dispute_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dispute_id UUID NOT NULL REFERENCES public.disputes(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL CHECK (event_type IN ('opened', 'message', 'evidence_uploaded', 'under_review', 'resolved')),
    comment TEXT NOT NULL,
    attachments JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.dispute_events IS 'Timeline com mensagens, envio de provas e decisões de mediação da disputa';

CREATE INDEX IF NOT EXISTS idx_disputes_contract ON public.disputes(contract_id);
CREATE INDEX IF NOT EXISTS idx_dispute_events_dispute ON public.dispute_events(dispute_id, created_at ASC);

ALTER TABLE public.disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dispute_events ENABLE ROW LEVEL SECURITY;

-- RLS para Disputes
DROP POLICY IF EXISTS "Participants can view disputes" ON public.disputes;
CREATE POLICY "Participants can view disputes"
    ON public.disputes
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.contracts c
            WHERE c.id = disputes.contract_id
            AND (c.client_id = auth.uid() OR c.freelancer_id = auth.uid())
        )
    );

DROP POLICY IF EXISTS "Participants can insert disputes" ON public.disputes;
CREATE POLICY "Participants can insert disputes"
    ON public.disputes
    FOR INSERT
    WITH CHECK (
        auth.uid() = opened_by AND
        EXISTS (
            SELECT 1 FROM public.contracts c
            WHERE c.id = disputes.contract_id
            AND (c.client_id = auth.uid() OR c.freelancer_id = auth.uid())
        )
    );

-- RLS para Dispute Events
DROP POLICY IF EXISTS "Participants can view dispute events" ON public.dispute_events;
CREATE POLICY "Participants can view dispute events"
    ON public.dispute_events
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.disputes d
            JOIN public.contracts c ON c.id = d.contract_id
            WHERE d.id = dispute_events.dispute_id
            AND (c.client_id = auth.uid() OR c.freelancer_id = auth.uid())
        )
    );

DROP POLICY IF EXISTS "Participants can insert dispute events" ON public.dispute_events;
CREATE POLICY "Participants can insert dispute events"
    ON public.dispute_events
    FOR INSERT
    WITH CHECK (
        auth.uid() = user_id AND
        EXISTS (
            SELECT 1 FROM public.disputes d
            JOIN public.contracts c ON c.id = d.contract_id
            WHERE d.id = dispute_events.dispute_id
            AND (c.client_id = auth.uid() OR c.freelancer_id = auth.uid())
        )
    );

-- Trigger: Quando uma disputa é aberta, congela o contrato automaticamente e cria o evento inicial
CREATE OR REPLACE FUNCTION public.handle_dispute_opened_trigger()
RETURNS TRIGGER AS $$
BEGIN
    -- Congelar status do contrato para 'in_dispute'
    UPDATE public.contracts
    SET status = 'in_dispute'
    WHERE id = NEW.contract_id;

    -- Criar evento inicial na timeline
    INSERT INTO public.dispute_events (
        dispute_id,
        user_id,
        event_type,
        comment,
        attachments
    ) VALUES (
        NEW.id,
        NEW.opened_by,
        'opened',
        COALESCE(NEW.description, NEW.reason),
        COALESCE(NEW.evidence_attachments, '[]'::jsonb)
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_dispute_opened ON public.disputes;
CREATE TRIGGER trg_dispute_opened
    AFTER INSERT ON public.disputes
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_dispute_opened_trigger();

-- ============================================================================
-- 6. CONTRAPROPOSTAS (PROPOSAL COUNTER OFFERS)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.proposal_counter_offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    proposal_id UUID NOT NULL REFERENCES public.proposals(id) ON DELETE CASCADE,
    offered_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount NUMERIC(10,2) NOT NULL,
    estimated_days INT NOT NULL DEFAULT 14,
    milestones JSONB DEFAULT '[]'::jsonb,
    message TEXT,
    status TEXT NOT NULL CHECK (status IN ('pending', 'accepted', 'rejected', 'superseded')) DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.proposal_counter_offers IS 'Registro de contrapropostas negociadas entre cliente e freelancer';

CREATE INDEX IF NOT EXISTS idx_proposal_counter_offers_proposal ON public.proposal_counter_offers(proposal_id, created_at DESC);

ALTER TABLE public.proposal_counter_offers ENABLE ROW LEVEL SECURITY;

-- RLS: Participantes da proposta podem visualizar contrapropostas
DROP POLICY IF EXISTS "Participants can view counter offers" ON public.proposal_counter_offers;
CREATE POLICY "Participants can view counter offers"
    ON public.proposal_counter_offers
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.proposals p
            JOIN public.jobs j ON j.id = p.job_id
            WHERE p.id = proposal_counter_offers.proposal_id
            AND (j.client_id = auth.uid() OR p.freelancer_id = auth.uid())
        )
    );

-- RLS: Cliente ou freelancer podem enviar contraproposta
DROP POLICY IF EXISTS "Participants can insert counter offers" ON public.proposal_counter_offers;
CREATE POLICY "Participants can insert counter offers"
    ON public.proposal_counter_offers
    FOR INSERT
    WITH CHECK (
        auth.uid() = offered_by AND
        EXISTS (
            SELECT 1 FROM public.proposals p
            JOIN public.jobs j ON j.id = p.job_id
            WHERE p.id = proposal_counter_offers.proposal_id
            AND (j.client_id = auth.uid() OR p.freelancer_id = auth.uid())
        )
    );

-- RLS: Participantes podem atualizar o status da contraproposta (aceitar/recusar)
DROP POLICY IF EXISTS "Participants can update counter offers" ON public.proposal_counter_offers;
CREATE POLICY "Participants can update counter offers"
    ON public.proposal_counter_offers
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.proposals p
            JOIN public.jobs j ON j.id = p.job_id
            WHERE p.id = proposal_counter_offers.proposal_id
            AND (j.client_id = auth.uid() OR p.freelancer_id = auth.uid())
        )
    );
