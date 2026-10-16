// Cancela a assinatura Pro do usuário autenticado. O plano segue ativo até o fim do período já pago.
import { adminClient, asaas, handle, HttpError, json, requireUser } from "../_shared/common.ts";

Deno.serve(handle(async (req) => {
  const user = await requireUser(req);
  const admin = adminClient();

  const { data: sub } = await admin
    .from("subscriptions")
    .select("id, asaas_subscription_id")
    .eq("user_id", user.id)
    .in("status", ["pending", "active", "overdue"])
    .maybeSingle();
  if (!sub) throw new HttpError(404, "Nenhuma assinatura ativa encontrada.");

  await asaas(`/subscriptions/${sub.asaas_subscription_id}`, { method: "DELETE" });
  await admin.from("subscriptions").update({ status: "cancelled" }).eq("id", sub.id);
  return json({ ok: true });
}));
