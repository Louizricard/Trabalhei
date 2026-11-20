-- Relatórios de bug enviados pelo app (Perfil > Reportar um bug).
-- Quem envia: qualquer usuário logado, só em nome da própria conta.
-- Quem lê: só administradores (is_admin), pela aba Bugs do /admin. O próprio
-- autor não lê de volta: o relatório pode citar dados que só a equipe vê.
-- A captura de tela fica no bucket privado bug_reports, em <uid>/<arquivo>.
-- Excluir a conta apaga os relatórios (cascade) e a pasta do usuário no
-- storage (account_deletion_objects já cobre <uid>/%).

create table public.bug_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  description text not null check (char_length(btrim(description)) between 10 and 4000),
  screenshot_path text check (
    screenshot_path is null
    or (char_length(screenshot_path) <= 300 and split_part(screenshot_path, '/', 1) = user_id::text)
  ),
  platform text not null check (platform in ('android', 'ios', 'web', 'windows', 'macos', 'linux')),
  app_version text check (app_version is null or char_length(app_version) <= 40),
  status text not null default 'open' check (status in ('open', 'resolved')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
create index bug_reports_status_created_idx on public.bug_reports (status, created_at desc);
create index bug_reports_user_created_idx on public.bug_reports (user_id, created_at desc);

alter table public.bug_reports enable row level security;

-- Envio: só como a própria conta e sempre aberto.
create policy bug_reports_insert_own on public.bug_reports
  for insert to authenticated
  with check (user_id = (select auth.uid()) and status = 'open' and resolved_at is null);

-- Leitura e triagem: só administradores.
create policy bug_reports_select_admin on public.bug_reports
  for select to authenticated using ((select public.is_admin()));
create policy bug_reports_update_admin on public.bug_reports
  for update to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

revoke all on public.bug_reports from anon;
revoke update, delete on public.bug_reports from authenticated;
grant update (status, resolved_at) on public.bug_reports to authenticated;

-- Limite contra abuso: até 5 relatórios por hora por conta.
create function public.bug_reports_rate_limit()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (select count(*) from public.bug_reports
      where user_id = new.user_id and created_at > now() - interval '1 hour') >= 5 then
    raise exception 'BUG_REPORT_RATE_LIMIT';
  end if;
  return new;
end;
$$;
revoke all on function public.bug_reports_rate_limit() from public, anon, authenticated;
create trigger bug_reports_rate_limit before insert on public.bug_reports
  for each row execute function public.bug_reports_rate_limit();

-- ---------------------------------------------------------------- Storage
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('bug_reports', 'bug_reports', false, 5242880, array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Upload só na própria pasta; o autor pode apagar o próprio arquivo (envio
-- que falhou no meio). Leitura só para administradores.
create policy storage_insert_bug_reports_own on storage.objects
  for insert to authenticated with check (
    bucket_id = 'bug_reports' and (storage.foldername(name))[1] = (select auth.uid())::text
  );
create policy storage_delete_bug_reports_own on storage.objects
  for delete to authenticated using (
    bucket_id = 'bug_reports' and (storage.foldername(name))[1] = (select auth.uid())::text
  );
create policy storage_read_bug_reports_admin on storage.objects
  for select to authenticated using (bucket_id = 'bug_reports' and (select public.is_admin()));

-- ---------------------------------------------------------------- Admin
-- Lista para a aba Bugs do /admin, com o nome de quem enviou.
create function public.admin_list_bug_reports(p_status text default 'open')
returns table (
  id uuid, description text, screenshot_path text, platform text,
  app_version text, status text, created_at timestamptz, resolved_at timestamptz,
  user_id uuid, user_name text
)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.require_admin();
  return query
  select b.id, b.description, b.screenshot_path, b.platform, b.app_version,
    b.status, b.created_at, b.resolved_at, b.user_id, p.full_name
  from public.bug_reports b
  left join public.profiles p on p.id = b.user_id
  where b.status = p_status
  order by b.created_at desc
  limit 200;
end;
$$;
revoke all on function public.admin_list_bug_reports(text) from public, anon;
grant execute on function public.admin_list_bug_reports(text) to authenticated;
