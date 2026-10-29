create or replace function billing_private.apply_feature_payment(p_event_id text,p_payment jsonb)
returns text language plpgsql security definer set search_path='' as $$
declare f public.job_featurings; v_start timestamptz; v_until timestamptz;
begin
  select * into f from public.job_featurings where asaas_payment_id=p_payment->>'id' for update;
  if not found then return 'pending'; end if;
  if exists(select 1 from public.billing_payment_receipts
    where payment_id=p_payment->>'id' and revoked_at is not null) then return 'processed'; end if;
  if f.status='paid' then return 'processed'; end if;
  select greatest(coalesce(featured_until,now()),now()) into strict v_start
    from public.jobs where id=f.job_id for update;
  v_until:=v_start+make_interval(days=>f.days);
  insert into public.billing_payment_receipts
    (payment_id,product,event_id,expires_at,feature_starts_at,feature_original_expires_at)
    values(p_payment->>'id','job_feature',p_event_id,v_until,v_start,v_until)
    on conflict(payment_id) do nothing;
  if not found then return 'processed'; end if;
  update public.jobs set featured_until=v_until where id=f.job_id;
  update public.job_featurings set status='paid',paid_at=now() where id=f.id;
  perform public.notify(f.user_id,'system','Vaga patrocinada ativa',
    'Pagamento confirmado. Sua vaga já está no espaço de vagas patrocinadas do mural.',
    jsonb_build_object('job_id',f.job_id,'route','/jobs/'||f.job_id));
  return 'processed';
end;
$$;

create function billing_private.remove_feature_period(p_feature public.job_featurings,p_receipt public.billing_payment_receipts)
returns numeric language plpgsql security definer set search_path='' as $$
declare v_until timestamptz; v_remove interval;
begin
  select featured_until into strict v_until from public.jobs where id=p_feature.job_id for update;
  if p_receipt.feature_starts_at is null then raise exception 'FEATURE_PERIOD_UNKNOWN'; end if;
  v_remove:=least(greatest(p_receipt.expires_at-greatest(now(),p_receipt.feature_starts_at),interval '0'),
    greatest(coalesce(v_until,now())-now(),interval '0'));
  if v_remove>interval '0' then
    update public.jobs set featured_until=greatest(now(),v_until-v_remove) where id=p_feature.job_id;
    -- Compacta a linha do tempo, preservando a duração das compras posteriores.
    update public.billing_payment_receipts r set feature_starts_at=r.feature_starts_at-v_remove,
      expires_at=r.expires_at-v_remove
    from public.job_featurings f where r.payment_id=f.asaas_payment_id and f.job_id=p_feature.job_id
      and r.product='job_feature' and r.payment_id<>p_receipt.payment_id and r.revoked_at is null
      and r.feature_starts_at>=p_receipt.expires_at;
  end if;
  return extract(epoch from v_remove);
end;
$$;

create function billing_private.apply_feature_refund(p_event_id text,p_payment jsonb)
returns text language plpgsql security definer set search_path='' as $$
declare f public.job_featurings; r public.billing_payment_receipts; v_seconds numeric:=0;
begin
  select * into f from public.job_featurings where asaas_payment_id=p_payment->>'id' for update;
  if not found then return 'pending'; end if;
  if f.amount=0 then return 'ignored'; end if;
  perform 1 from public.jobs where id=f.job_id for update;
  select * into r from public.billing_payment_receipts where payment_id=p_payment->>'id' for update;
  if found then
    if r.product<>'job_feature' then raise exception 'RECEIPT_PRODUCT_CONFLICT'; end if;
    if r.revoked_at is not null then return 'processed'; end if;
    v_seconds:=billing_private.remove_feature_period(f,r);
  else
    if f.status='paid' then raise exception 'FEATURE_RECEIPT_MISSING'; end if;
    -- Estorno anterior à confirmação: tombstone impede concessão tardia.
    insert into public.billing_payment_receipts
      (payment_id,product,event_id,expires_at,feature_starts_at,feature_original_expires_at)
      values(p_payment->>'id','job_feature',p_event_id,now(),now(),now());
  end if;
  update public.billing_payment_receipts set revoked_at=now(),revocation_event_id=p_event_id,
    revoked_seconds=v_seconds where payment_id=p_payment->>'id';
  update public.job_featurings set status='cancelled' where id=f.id;
  perform public.notify(f.user_id,'system','Estorno do destaque confirmado',
    'O período desta compra foi encerrado. Outros destaques válidos da vaga foram preservados.',
    jsonb_build_object('job_id',f.job_id,'route','/jobs/'||f.job_id));
  return 'processed';
end;
$$;
revoke all on function billing_private.apply_feature_payment(text,jsonb),
  billing_private.remove_feature_period(public.job_featurings,public.billing_payment_receipts),
  billing_private.apply_feature_refund(text,jsonb) from public,anon,authenticated,service_role;
