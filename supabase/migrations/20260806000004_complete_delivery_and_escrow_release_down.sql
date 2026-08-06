-- Migration Down: 20260806000004_complete_delivery_and_escrow_release_down.sql
DROP FUNCTION IF EXISTS public.release_escrow_milestone(UUID);
