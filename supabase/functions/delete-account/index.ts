// Exclui a conta do usuário autenticado (LGPD). Regras de dados em
// supabase/migrations/*_account_deletion.sql (função delete_account_data).
import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { adminClient, cancelOpenSubscription, handle, HttpError, json, requireUser } from "../_shared/common.ts";

// Buckets com arquivos do usuário em <bucket>/<user_id>/...
const ALL_BUCKETS = ["avatars", "portfolio", "job_attachments", "job_covers", "chat_attachments"];
// Com histórico de contratos, anexos de vagas e do chat ficam para a outra parte.
const PROFILE_BUCKETS = ["avatars", "portfolio"];

Deno.serve(handle(async (req) => {
  const user = await requireUser(req);
  const admin = adminClient();

  const { count } = await admin
    .from("contracts")
    .select("id", { count: "exact", head: true })
    .eq("status", "active")
    .or(`client_id.eq.${user.id},freelancer_id.eq.${user.id}`);
  if (count) {
    throw new HttpError(
      409,
      "Você tem contratos em andamento. Conclua-os antes de excluir a conta ou fale com o suporte.",
    );
  }

  await cancelOpenSubscription(admin, user.id);

  const { data: hardDelete, error } = await admin.rpc("delete_account_data", { p_user: user.id });
  if (error) {
    throw new HttpError(500, "Não foi possível excluir a conta. Tente novamente.", { cause: error });
  }

  await removeUserFiles(admin, user.id, hardDelete ? ALL_BUCKETS : PROFILE_BUCKETS);

  // Sem contratos: apaga de vez (cascade). Com contratos: soft delete, que
  // descarta e-mail e identidades mas mantém o id referenciado pelos contratos.
  const { error: authError } = await admin.auth.admin.deleteUser(user.id, !hardDelete);
  if (authError) {
    throw new HttpError(500, "Não foi possível excluir a conta. Tente novamente.", { cause: authError });
  }
  return json({ ok: true });
}));

async function removeUserFiles(admin: SupabaseClient, userId: string, buckets: string[]) {
  for (const bucket of buckets) {
    const paths = await listFilesRecursive(admin, bucket, userId);
    for (let i = 0; i < paths.length; i += 100) {
      const { error } = await admin.storage.from(bucket).remove(paths.slice(i, i + 100));
      if (error) console.error("[delete-account] storage", bucket, error);
    }
  }
}

async function listFilesRecursive(admin: SupabaseClient, bucket: string, prefix: string): Promise<string[]> {
  const files: string[] = [];
  for (let offset = 0; ; offset += 1000) {
    const { data, error } = await admin.storage.from(bucket).list(prefix, { limit: 1000, offset });
    if (error || !data?.length) break;
    for (const item of data) {
      const path = `${prefix}/${item.name}`;
      // Pastas vêm sem id na listagem do Storage.
      if (item.id) files.push(path);
      else files.push(...await listFilesRecursive(admin, bucket, path));
    }
    if (data.length < 1000) break;
  }
  return files;
}
