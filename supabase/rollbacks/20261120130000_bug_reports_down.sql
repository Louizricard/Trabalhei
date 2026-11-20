-- Desfaz 20261120130000_bug_reports. Recusa rodar se já houver relatórios ou
-- capturas de tela (seriam perdidos).
do $$
begin
  if exists (select 1 from public.bug_reports)
     or exists (select 1 from storage.objects where bucket_id = 'bug_reports') then
    raise exception 'BUG_REPORTS_DATA_PRESENT';
  end if;
end $$;

drop function if exists public.admin_list_bug_reports(text);
drop policy if exists storage_read_bug_reports_admin on storage.objects;
drop policy if exists storage_delete_bug_reports_own on storage.objects;
drop policy if exists storage_insert_bug_reports_own on storage.objects;
delete from storage.buckets where id = 'bug_reports';
drop table if exists public.bug_reports;
drop function if exists public.bug_reports_rate_limit();
