-- As policies de proposal_templates e client_notes chamam is_pro(); quem
-- avalia a policy é o próprio usuário logado, que precisa poder executá-la.
-- Ser Pro já é público (profiles.plan).
grant execute on function public.is_pro(uuid) to authenticated;
