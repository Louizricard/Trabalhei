create function billing_private.change_feature_credit(p_event public.billing_events,p_payment jsonb,p_action text)
returns text language plpgsql security definer set search_path='' as $$
declare f public.job_featurings; r public.billing_payment_receipts; v_seconds numeric:=0; v_start timestamptz;
begin
  select * into f from public.job_featurings where asaas_payment_id=p_payment->>'id' for update;
  if not found then return 'pending'; end if;
  if f.amount=0 then return 'ignored'; end if;
  perform 1 from public.jobs where id=f.job_id for update;
  select * into r from public.billing_payment_receipts where payment_id=f.asaas_payment_id for update;
  if found and r.product<>'job_feature' then raise exception 'RECEIPT_PRODUCT_CONFLICT'; end if;
  if not found then
    if f.status='paid' then raise exception 'FEATURE_RECEIPT_MISSING'; end if;
    insert into public.billing_payment_receipts(payment_id,product,event_id,expires_at,
      feature_starts_at,feature_original_expires_at,benefit_applied)
      values(f.asaas_payment_id,'job_feature',p_event.id,now(),now(),now(),false) returning * into r;
  end if;
  p_action:=billing_private.reversal_transition(r,p_event,p_action);
  if p_action='skip' then return 'processed'; end if;
  if p_action='pending' then return 'pending'; end if;
  if p_action='restore' then
    return billing_private.restore_feature_credit(f,r,p_event.id);
  end if;
  if r.revoked_at is null and r.benefit_applied then
    v_seconds:=billing_private.remove_feature_period(f,r);
  else v_seconds:=r.revoked_seconds; end if;
  update public.billing_payment_receipts set revoked_at=coalesce(revoked_at,now()),
    revocation_event_id=p_event.id,revoked_seconds=v_seconds where payment_id=r.payment_id;
  update public.job_featurings set status='cancelled' where id=f.id;
  perform public.notify(f.user_id,'system','Pagamento do destaque atualizado',
    'O benefício desta cobrança foi suspenso ou encerrado. Outros destaques válidos foram preservados.',
    jsonb_build_object('job_id',f.job_id,'route','/jobs/'||f.job_id));
  return 'processed';
end;
$$;

create function billing_private.restore_feature_credit(f public.job_featurings,r public.billing_payment_receipts,p_event text)
returns text language plpgsql security definer set search_path='' as $$
declare v_start timestamptz; v_duration interval; v_until timestamptz;
begin
  select greatest(coalesce(featured_until,now()),now()) into v_start from public.jobs where id=f.job_id;
  v_duration:=case when r.benefit_applied then make_interval(secs=>least(r.revoked_seconds,
    greatest(extract(epoch from(r.expires_at-now())),0))::double precision) else make_interval(days=>f.days) end;
  v_until:=v_start+v_duration;
  update public.jobs set featured_until=v_until where id=f.job_id;
  update public.billing_payment_receipts set revoked_at=null,benefit_applied=true,
    feature_starts_at=v_start,expires_at=v_until where payment_id=r.payment_id;
  update public.job_featurings set status='paid',paid_at=coalesce(paid_at,now()) where id=f.id;
  perform public.notify(f.user_id,'system','Destaque após disputa',
    'A confirmação do repasse foi recebida. O prazo válido desta compra foi recuperado.',
    jsonb_build_object('job_id',f.job_id,'route','/jobs/'||f.job_id));
  return 'processed';
end;
$$;
revoke all on function billing_private.change_feature_credit(public.billing_events,jsonb,text),
  billing_private.restore_feature_credit(public.job_featurings,public.billing_payment_receipts,text)
  from public,anon,authenticated,service_role;
