// Cancela a assinatura Pro do usuário autenticado. O plano segue ativo até o fim do período já pago.
import { adminClient, cancelOpenSubscription, handle, HttpError, json, requireUser } from "../_shared/common.ts";

Deno.serve(handle(async (req) => {
  const user = await requireUser(req);
  const cancelled = await cancelOpenSubscription(adminClient(), user.id);
  if (!cancelled) throw new HttpError(404, "Nenhuma assinatura ativa encontrada.");
  return json({ ok: true });
}));
