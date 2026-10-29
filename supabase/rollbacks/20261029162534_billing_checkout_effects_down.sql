do $$ begin
  if exists(select 1 from public.job_featurings where amount=0) then
    raise exception 'FREE_FEATURE_DATA_PRESENT: preserve o novo schema e o diário; não apague benefícios';
  end if;
end $$;
drop function public.finish_billing_checkout(uuid,uuid,jsonb);
drop function public.link_billing_checkout(uuid,uuid,text);
drop function public.price_billing_checkout(uuid,uuid);
alter table public.job_featurings drop constraint job_featurings_amount_check;
alter table public.job_featurings add constraint job_featurings_amount_check check(amount>0);
