-- O prazo original é preservado para auditoria; o prazo corrente pode ser
-- antecipado quando um período anterior da mesma vaga é estornado.
alter table public.billing_payment_receipts
  add column feature_starts_at timestamptz,
  add column feature_original_expires_at timestamptz,
  add column revoked_at timestamptz,
  add column revocation_event_id text references public.billing_events(id) on delete set null,
  add column revoked_seconds numeric not null default 0 check(revoked_seconds>=0),
  add constraint feature_receipt_interval check(feature_starts_at is null or feature_starts_at<=expires_at);
create index billing_receipts_revocation_event_idx on public.billing_payment_receipts(revocation_event_id)
  where revocation_event_id is not null;

-- O seed antigo copiava o prazo agregado da vaga. Com vários períodos ativos,
-- não é possível atribuir essa duração com segurança sem conciliação.
do $$ begin
  if exists(select 1 from public.billing_payment_receipts r
    join public.job_featurings f on f.asaas_payment_id=r.payment_id
    where r.product='job_feature' and r.event_id is null and r.expires_at>now()
      and (select count(*) from public.job_featurings other
        where other.job_id=f.job_id and other.status='paid')>1) then
    raise exception 'RECONCILE_LEGACY_FEATURE_PERIODS';
  end if;
end $$;

update public.billing_payment_receipts r
set feature_starts_at=greatest(r.applied_at,r.expires_at-make_interval(days=>f.days)),
    feature_original_expires_at=r.expires_at
from public.job_featurings f
where r.payment_id=f.asaas_payment_id and r.product='job_feature';

-- Os novos campos continuam privados: a tabela já tem RLS e acesso só service_role.
