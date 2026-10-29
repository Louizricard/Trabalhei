-- Somente PostgreSQL local descartável. Estruturas gerenciadas pelo Supabase
-- necessárias à migration inicial; sem pg_net nem chamadas HTTP externas.
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role bypassrls; end if;
end $$;
create schema auth;
create table auth.users (
  id uuid primary key, email text, raw_user_meta_data jsonb default '{}'
);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
grant usage on schema auth to anon, authenticated, service_role;
create schema storage;
create table storage.buckets (
  id text primary key, name text, public boolean, file_size_limit bigint, allowed_mime_types text[]
);
create table storage.objects (id uuid primary key, bucket_id text, name text, owner uuid);
create function storage.foldername(text) returns text[] language sql immutable as $$
  select (string_to_array($1, '/'))[1:array_length(string_to_array($1, '/'), 1)-1]
$$;
create publication supabase_realtime;
