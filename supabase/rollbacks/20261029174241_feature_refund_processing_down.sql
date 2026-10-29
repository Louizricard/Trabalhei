do $$ begin
  if exists(select 1 from public.billing_payment_receipts where revoked_at is not null) then
    raise exception 'FEATURE_REFUND_DATA_PRESENT';
  end if;
end $$;
create or replace function billing_private.apply_feature_payment(p_event_id text, p_payment jsonb)
returns text language plpgsql security definer set search_path = '' as $$
declare
  f public.job_featurings;
  v_until timestamptz;
begin
  select * into f from public.job_featurings
    where asaas_payment_id = p_payment ->> 'id' for update;
  if not found then return 'pending'; end if;
  if f.status = 'paid' then return 'processed'; end if;
  select greatest(coalesce(featured_until, now()), now()) + make_interval(days => f.days)
    into strict v_until from public.jobs where id = f.job_id for update;
  insert into public.billing_payment_receipts (payment_id, product, event_id, expires_at)
    values (p_payment ->> 'id', 'job_feature', p_event_id, v_until)
    on conflict (payment_id) do nothing;
  if not found then return 'processed'; end if;
  update public.jobs set featured_until = v_until where id = f.job_id;
  update public.job_featurings set status = 'paid', paid_at = now() where id = f.id;
  perform public.notify(f.user_id, 'system', 'Vaga patrocinada ativa',
    'Pagamento confirmado. Sua vaga já está no espaço de vagas patrocinadas do mural.',
    jsonb_build_object('job_id', f.job_id, 'route', '/jobs/' || f.job_id));
  return 'processed';
end;
$$;
drop function billing_private.apply_feature_refund(text,jsonb);
drop function billing_private.remove_feature_period(public.job_featurings,public.billing_payment_receipts);

