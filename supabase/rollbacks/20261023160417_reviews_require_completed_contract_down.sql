-- Rollback: volta a permitir avaliação em qualquer status do contrato.
drop policy if exists reviews_insert on public.reviews;
create policy reviews_insert on public.reviews
  for insert to authenticated with check (
    reviewer_id = auth.uid()
    and exists (
      select 1 from public.contracts c
      where c.id = contract_id
        and ((c.client_id = reviewer_id and c.freelancer_id = target_id)
          or (c.freelancer_id = reviewer_id and c.client_id = target_id))
    )
  );
