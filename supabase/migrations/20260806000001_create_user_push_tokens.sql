-- Migration: Create user_push_tokens table for Firebase Cloud Messaging (FCM) push notifications
-- Description: Stores FCM device tokens associated with authenticated users for push notifications
-- Up Migration

CREATE TABLE IF NOT EXISTS public.user_push_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE,
    platform TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'web', 'macos', 'windows', 'linux')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Comments describing purpose
COMMENT ON TABLE public.user_push_tokens IS 'Stores FCM push notification device tokens per user';
COMMENT ON COLUMN public.user_push_tokens.user_id IS 'References the authenticated user in auth.users';
COMMENT ON COLUMN public.user_push_tokens.token IS 'Unique Firebase Cloud Messaging device registration token';
COMMENT ON COLUMN public.user_push_tokens.platform IS 'Client platform operating system (android, ios, web)';

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_user_push_tokens_user_id ON public.user_push_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_user_push_tokens_token ON public.user_push_tokens(token);

-- Enable Row Level Security
ALTER TABLE public.user_push_tokens ENABLE ROW LEVEL SECURITY;

-- RLS Policies:
-- 1. SELECT: Users can only view their own registered push tokens
CREATE POLICY "Users can select own push tokens"
    ON public.user_push_tokens
    FOR SELECT
    USING (auth.uid() = user_id);

-- 2. INSERT: Users can only insert tokens for their own account
CREATE POLICY "Users can insert own push tokens"
    ON public.user_push_tokens
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 3. UPDATE: Users can only update their own tokens
CREATE POLICY "Users can update own push tokens"
    ON public.user_push_tokens
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 4. DELETE: Users can delete their own tokens (e.g. on logout)
CREATE POLICY "Users can delete own push tokens"
    ON public.user_push_tokens
    FOR DELETE
    USING (auth.uid() = user_id);

-- Trigger to maintain updated_at column
CREATE OR REPLACE FUNCTION public.handle_user_push_tokens_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_user_push_tokens_updated_at ON public.user_push_tokens;
CREATE TRIGGER trg_user_push_tokens_updated_at
    BEFORE UPDATE ON public.user_push_tokens
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_user_push_tokens_updated_at();
