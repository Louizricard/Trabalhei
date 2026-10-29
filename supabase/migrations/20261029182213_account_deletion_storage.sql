create function public.account_deletion_objects(p_user uuid,p_token uuid)
returns table(bucket_id text,name text) language plpgsql security definer set search_path='' as $$
declare r public.account_deletion_requests;
begin
  r:=account_private.deletion_request(p_user,p_token);
  return query select o.bucket_id,o.name from storage.objects o
    where (o.owner=p_user or o.owner_id=p_user::text or o.name like p_user::text||'/%')
      and (r.hard_delete or o.bucket_id not in('job_attachments','job_covers','chat_attachments'))
    order by o.bucket_id,o.name limit 100;
end;
$$;
create function public.prepare_account_auth_deletion(p_user uuid,p_token uuid)
returns void language plpgsql security definer set search_path='' as $$
declare r public.account_deletion_requests; v_hard boolean;
begin
  r:=account_private.deletion_request(p_user,p_token);
  if exists(select 1 from public.account_deletion_objects(p_user,p_token)) then raise exception 'STORAGE_NOT_EMPTY'; end if;
  v_hard:=public.delete_account_data(p_user);
  if v_hard<>r.hard_delete then raise exception 'DELETION_HISTORY_CHANGED'; end if;
  if not r.hard_delete then
    -- Apenas propriedade dos anexos retidos: o conteúdo permanece acessível
    -- à outra parte pela policy da conversa/contrato, sem pertencer ao Auth excluído.
    update storage.objects set owner=null,owner_id=null
      where bucket_id in('job_attachments','job_covers','chat_attachments')
        and (owner=p_user or owner_id=p_user::text or name like p_user::text||'/%');
  end if;
  update public.account_deletion_requests set phase='auth',updated_at=now() where user_id=p_user;
end;
$$;
revoke all on function public.account_deletion_objects(uuid,uuid),public.prepare_account_auth_deletion(uuid,uuid)
  from public,anon,authenticated;
grant execute on function public.account_deletion_objects(uuid,uuid),public.prepare_account_auth_deletion(uuid,uuid) to service_role;
