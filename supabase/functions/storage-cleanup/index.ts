import { adminClient, isServiceRole, json } from "../_shared/common.ts";
import { createCleanupHandler } from "./handler.ts";

const admin = adminClient();

Deno.serve(createCleanupHandler({
  authorize: isServiceRole,
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
