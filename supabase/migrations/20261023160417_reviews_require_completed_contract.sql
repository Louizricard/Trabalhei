-- ============================================================================
-- Avaliações só depois da conclusão do contrato.
--
-- Antes, qualquer parte de um contrato podia avaliar a outra a qualquer
-- momento. Agora o INSERT em `reviews` exige `contracts.status = 'completed'`,
-- que só é atingido quando o último marco é aprovado (approve_milestone).
-- ============================================================================

drop policy if exists reviews_insert on public.reviews;
create policy reviews_insert on public.reviews
  for insert to authenticated with check (
    reviewer_id = auth.uid()
    and exists (
      select 1 from public.contracts c
      where c.id = contract_id
        and c.status = 'completed'
        and ((c.client_id = reviewer_id and c.freelancer_id = target_id)
          or (c.freelancer_id = reviewer_id and c.client_id = target_id))
    )
  );
