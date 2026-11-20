// O app Android envia o token logo após a compra no Google Play; o benefício só é concedido
// depois de conferido na API do Google (ver docs/play-billing.md).
import { handle, HttpError, json, requireUser } from "../_shared/common.ts";
import { playDeps } from "../_shared/play_deps.ts";
import { PurchaseError, verifyFromApp } from "../_shared/play_purchases.ts";

Deno.serve(handle(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "Método não permitido.");
  const user = await requireUser(req);
  const body = await req.json().catch(() => null);
  try {
    return json(await verifyFromApp(playDeps(), user.id, body));
  } catch (error) {
    if (error instanceof PurchaseError) throw new HttpError(error.status, error.message);
    throw error;
  }
}));
