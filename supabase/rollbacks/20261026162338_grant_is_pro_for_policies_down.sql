-- Desfaz 20261026162338_grant_is_pro_for_policies (as policies Pro passam a falhar).
revoke execute on function public.is_pro(uuid) from authenticated;
