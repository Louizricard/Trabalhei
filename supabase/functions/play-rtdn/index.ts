// Notificações em tempo real do Google Play (Pub/Sub push). A URL de inscrição leva
// ?token=<PLAY_RTDN_TOKEN>. Erro transitório responde 500 para o Pub/Sub reenviar; mensagem
// que nunca vai dar certo responde 200 e vai para o Sentry.
import { env, handle, HttpError, json, reportError } from "../_shared/common.ts";
import { playDeps } from "../_shared/play_deps.ts";
import { handleNotification, PurchaseError } from "../_shared/play_purchases.ts";

async function sameSecret(a: string, b: string) {
  const digest = (v: string) => crypto.subtle.digest("SHA-256", new TextEncoder().encode(v));
  const [x, y] = (await Promise.all([digest(a), digest(b)])).map((d) => new Uint8Array(d));
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}

Deno.serve(handle(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "Método não permitido.");
  const token = new URL(req.url).searchParams.get("token") ?? "";
  if (!(await sameSecret(token, env("PLAY_RTDN_TOKEN")))) throw new HttpError(401, "Não autorizado.");
  const payload = await req.json().catch(() => null);
  try {
    return json({ result: await handleNotification(playDeps(), payload) });
  } catch (error) {
    if (error instanceof PurchaseError) {
      await reportError("play-rtdn", error, { status: error.status });
      return json({ result: "rejected" });
    }
    throw error;
  }
}));
