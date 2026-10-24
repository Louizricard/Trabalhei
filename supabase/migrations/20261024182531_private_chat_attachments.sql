-- ============================================================================
-- chat_attachments passa a ser privado.
--
-- Arquivos do chat, entregas e pedidos de revisão podem ser confidenciais.
-- Sem leitura pública, o app gera URLs assinadas (1 h) na hora de exibir.
-- Leitura liberada só para:
--   * o dono do arquivo (primeira pasta = auth.uid());
--   * as partes da conversa: <dono>/<conversation_id>/<arquivo>;
--   * as partes do contrato: <dono>/deliverables|revisions/<milestone_id>/<arquivo>.
-- As subconsultas respeitam o RLS de conversations/contracts/milestones, que
-- já restringe essas linhas às partes envolvidas.
-- ============================================================================

update storage.buckets set public = false where id = 'chat_attachments';

drop policy if exists "storage_read_public_buckets" on storage.objects;
create policy "storage_read_public_buckets" on storage.objects
  for select using (bucket_id in ('avatars', 'portfolio', 'job_attachments', 'job_covers'));

create policy "storage_read_chat_attachments" on storage.objects
  for select to authenticated using (
    bucket_id = 'chat_attachments'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or exists (
        select 1 from public.conversations c
        where c.id::text = (storage.foldername(name))[2]
          and (select auth.uid()) in (c.client_id, c.freelancer_id)
      )
      or exists (
        select 1 from public.milestones m
        join public.contracts k on k.id = m.contract_id
        where (storage.foldername(name))[2] in ('deliverables', 'revisions')
          and m.id::text = (storage.foldername(name))[3]
          and (select auth.uid()) in (k.client_id, k.freelancer_id)
      )
    )
  );
