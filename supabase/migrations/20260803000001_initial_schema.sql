-- ============================================================================
-- Migration: 20260803000001_initial_schema.sql
-- Description: FreelanceFlow Complete Production Schema with RLS & Triggers
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. PROFILES (Extending auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('client', 'freelancer', 'admin')) DEFAULT 'freelancer',
    full_name TEXT NOT NULL DEFAULT 'Usuário',
    email TEXT NOT NULL DEFAULT '',
    avatar_url TEXT,
    phone TEXT,
    company_name TEXT,
    bio TEXT,
    hourly_rate NUMERIC(10,2) DEFAULT 0.00,
    skills TEXT[] DEFAULT '{}',
    rating NUMERIC(3,2) DEFAULT 5.00,
    completed_jobs_count INT DEFAULT 0,
    availability_status TEXT DEFAULT 'available' CHECK (availability_status IN ('available', 'busy', 'unavailable')),
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Trigger to create profile automatically on auth.users insert
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    new.id,
    COALESCE(new.email, ''),
    COALESCE(new.raw_user_meta_data->>'full_name', split_part(COALESCE(new.email, 'Usuário'), '@', 1)),
    COALESCE(new.raw_user_meta_data->>'role', 'freelancer')
  )
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      full_name = COALESCE(EXCLUDED.full_name, public.profiles.full_name),
      role = COALESCE(EXCLUDED.role, public.profiles.role);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 2. CATEGORIES & SKILLS
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    icon TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.skills (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. JOBS
CREATE TABLE IF NOT EXISTS public.jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Mobile',
    description TEXT NOT NULL,
    contract_type TEXT NOT NULL CHECK (contract_type IN ('fixed', 'hourly')) DEFAULT 'fixed',
    budget_min NUMERIC(10,2) NOT NULL,
    budget_max NUMERIC(10,2) NOT NULL,
    deadline_days INT NOT NULL DEFAULT 30,
    experience_level TEXT NOT NULL CHECK (experience_level IN ('junior', 'pleno', 'senior', 'all')) DEFAULT 'all',
    status TEXT NOT NULL CHECK (status IN ('open', 'in_progress', 'completed', 'cancelled')) DEFAULT 'open',
    visibility TEXT NOT NULL CHECK (visibility IN ('public', 'invite_only')) DEFAULT 'public',
    is_featured BOOLEAN DEFAULT false,
    is_urgent BOOLEAN DEFAULT false,
    skills_required TEXT[] DEFAULT '{}',
    screening_questions JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 4. PROPOSALS
CREATE TABLE IF NOT EXISTS public.proposals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
    freelancer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    bid_amount NUMERIC(10,2) NOT NULL,
    estimated_days INT NOT NULL DEFAULT 14,
    cover_letter TEXT NOT NULL,
    screening_answers JSONB DEFAULT '[]'::jsonb,
    proposed_milestones JSONB DEFAULT '[]'::jsonb,
    status TEXT NOT NULL CHECK (status IN ('pending', 'accepted', 'rejected', 'counter_offered')) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT unique_freelancer_job_proposal UNIQUE (job_id, freelancer_id)
);

-- 5. CONTRACTS
CREATE TABLE IF NOT EXISTS public.contracts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
    proposal_id UUID REFERENCES public.proposals(id) ON DELETE SET NULL,
    client_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    freelancer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    total_amount NUMERIC(10,2) NOT NULL,
    platform_fee NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    escrow_amount NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    status TEXT NOT NULL CHECK (status IN ('active', 'completed', 'in_dispute', 'cancelled')) DEFAULT 'active',
    started_at TIMESTAMPTZ DEFAULT now(),
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 6. MILESTONES
CREATE TABLE IF NOT EXISTS public.milestones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_id UUID NOT NULL REFERENCES public.contracts(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    amount NUMERIC(10,2) NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'funded_in_escrow', 'submitted', 'approved_and_released', 'disputed')) DEFAULT 'pending',
    due_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 7. CONVERSATIONS & MESSAGES
CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_id UUID REFERENCES public.contracts(id) ON DELETE SET NULL,
    participant_a UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    participant_b UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    last_message_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    attachment_url TEXT,
    message_type TEXT NOT NULL CHECK (message_type IN ('text', 'system_event', 'milestone_update')) DEFAULT 'text',
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 8. REVIEWS
CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_id UUID REFERENCES public.contracts(id) ON DELETE SET NULL,
    reviewer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    target_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT NOT NULL,
    public_response TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 9. TRANSACTIONS
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    contract_id UUID REFERENCES public.contracts(id) ON DELETE SET NULL,
    type TEXT NOT NULL CHECK (type IN ('deposit', 'escrow_hold', 'escrow_release', 'payout_pix', 'platform_fee')),
    amount NUMERIC(10,2) NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'completed', 'failed', 'refunded')) DEFAULT 'completed',
    pix_key TEXT,
    gateway_ref TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 10. PORTFOLIO ITEMS
CREATE TABLE IF NOT EXISTS public.portfolio_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    freelancer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    image_url TEXT NOT NULL,
    project_url TEXT,
    tags TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 11. DISPUTES
CREATE TABLE IF NOT EXISTS public.disputes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_id UUID NOT NULL REFERENCES public.contracts(id) ON DELETE CASCADE,
    opened_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('opened', 'under_review', 'resolved_refund', 'resolved_release')) DEFAULT 'opened',
    resolution_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_jobs_status ON public.jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_client ON public.jobs(client_id);
CREATE INDEX IF NOT EXISTS idx_jobs_created_at ON public.jobs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_proposals_job ON public.proposals(job_id);
CREATE INDEX IF NOT EXISTS idx_proposals_freelancer ON public.proposals(freelancer_id);
CREATE INDEX IF NOT EXISTS idx_contracts_job ON public.contracts(job_id);
CREATE INDEX IF NOT EXISTS idx_contracts_parties ON public.contracts(client_id, freelancer_id);
CREATE INDEX IF NOT EXISTS idx_milestones_contract ON public.milestones(contract_id);
CREATE INDEX IF NOT EXISTS idx_conversations_participants ON public.conversations(participant_a, participant_b);
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON public.messages(conversation_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_reviews_target ON public.reviews(target_id);
CREATE INDEX IF NOT EXISTS idx_transactions_user ON public.transactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_portfolio_freelancer ON public.portfolio_items(freelancer_id);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.proposals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.milestones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.portfolio_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disputes ENABLE ROW LEVEL SECURITY;
