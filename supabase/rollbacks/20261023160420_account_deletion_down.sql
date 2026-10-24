-- Rollback da exclusão de conta. Perfis já anonimizados continuam anonimizados;
-- apenas a marcação deleted_at é descartada.
drop function if exists public.delete_account_data(uuid);
drop index if exists public.profiles_active_role_idx;
alter table public.profiles drop column if exists deleted_at;
