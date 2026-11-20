import { adminClient, isServiceRole, json } from "../_shared/common.ts";
import { createCleanupHandler } from "./handler.ts";

const admin = adminClient();

// Aceita a chave service_role ou o token do agendamento (Vault, conferido no
// banco por storage_cleanup_token_ok; ver 20261120145320_storage_cleanup_schedule).
async function authorize(req: Request): Promise<boolean> {
  if (await isServiceRole(req)) return true;
  const token = req.headers.get("x-cleanup-token") ?? "";
  if (!token) return false;
  const { data, error } = await admin.rpc("storage_cleanup_token_ok", { p_token: token });
  return !error && data === true;
}

Deno.serve(createCleanupHandler({
  authorize,
  async batch(limit) {
    const { data, error } = await admin.rpc("storage_cleanup_batch", { p_limit: limit });
    if (error) throw error;
    return data ?? [];
  },
  async remove(bucket, paths) {
    const { error } = await admin.storage.from(bucket).remove(paths);
    if (error) throw error;
  },
  async report(done, failed, lastError) {
    const { error } = await admin.rpc("storage_cleanup_report", {
      p_done: done,
      p_failed: failed,
      p_error: lastError,
    });
    if (error) throw error;
  },
  reply: json,
}));
