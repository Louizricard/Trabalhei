// Regras de confirmação das compras do Google Play, sem dependência de rede/banco (testáveis).
// Usadas por play-billing (o app envia o token logo após a compra) e play-rtdn (notificações
// em tempo real do Google: renovação, cancelamento, estorno).
import {
  FEATURE_PRODUCT,
  type GooglePlay,
  PLAY_PACKAGE,
  PlayApiError,
  PRO_PRODUCT,
} from "./google_play.ts";

export class PurchaseError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

export interface PlayDeps {
  play: GooglePlay;
  rpc: (name: string, args: Record<string, unknown>) => Promise<Record<string, unknown>>;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function fetchOrReject<T>(load: () => Promise<T>): Promise<T> {
  try {
    return await load();
  } catch (error) {
    // Token inexistente/inválido para este app: o Google responde 400/404/410.
    if (error instanceof PlayApiError && [400, 404, 410].includes(error.status)) {
      throw new PurchaseError(400, "Compra não encontrada no Google Play.");
    }
    throw error;
  }
}

/** Confere uma assinatura no Google e grava o estado. `expectedUser` nulo = vem do Google. */
export async function syncSubscription(deps: PlayDeps, token: string, expectedUser: string | null) {
  const s = await fetchOrReject(() => deps.play.subscription(token));
  if (s.productId !== PRO_PRODUCT) throw new PurchaseError(400, "Produto inesperado.");
  const owner = s.accountId;
  if (!owner || !UUID.test(owner)) throw new PurchaseError(400, "Compra sem conta do Trabalhei.");
  if (expectedUser && owner !== expectedUser) throw new PurchaseError(403, "Compra de outra conta.");
  const expires = s.state === "active" || s.state === "cancelled" ? s.expiresAt : null;
  const result = await deps.rpc("apply_play_subscription", {
    p_user: owner,
    p_token: token,
    p_order: s.orderId,
    p_state: s.state,
    p_expires: expires,
  });
  // Sem reconhecimento em 3 dias o Google estorna sozinho: reconhece só depois de gravar.
  if (s.needsAck && (s.state === "active" || s.state === "cancelled")) {
    await deps.play.acknowledgeSubscription(PRO_PRODUCT, token);
  }
  return result;
}

/** Confere um Destaque no Google, aplica e consome (permite comprar de novo). */
export async function syncFeature(deps: PlayDeps, token: string, expectedUser: string | null) {
  const p = await fetchOrReject(() => deps.play.product(FEATURE_PRODUCT, token));
  if (p.purchaseState === 2) return { state: "pending" };
  if (p.purchaseState !== 0) throw new PurchaseError(400, "Compra cancelada no Google Play.");
  const owner = p.accountId;
  if (!owner || !UUID.test(owner)) throw new PurchaseError(400, "Compra sem conta do Trabalhei.");
  if (expectedUser && owner !== expectedUser) throw new PurchaseError(403, "Compra de outra conta.");
  if (!p.profileId || !UUID.test(p.profileId)) throw new PurchaseError(400, "Compra sem vaga.");
  const result = await deps.rpc("apply_play_feature", {
    p_user: owner,
    p_token: token,
    p_order: p.orderId,
    p_job: p.profileId,
  });
  if (!p.consumed) await deps.play.consumeProduct(FEATURE_PRODUCT, token);
  return result;
}

/** Corpo enviado pelo app: { product, purchase_token }. */
export async function verifyFromApp(deps: PlayDeps, user: string, body: unknown) {
  const b = (body ?? {}) as Record<string, unknown>;
  const token = typeof b.purchase_token === "string" ? b.purchase_token.trim() : "";
  if (!token || token.length > 4096) throw new PurchaseError(400, "Token de compra inválido.");
  if (b.product === PRO_PRODUCT) return await syncSubscription(deps, token, user);
  if (b.product === FEATURE_PRODUCT) return await syncFeature(deps, token, user);
  throw new PurchaseError(400, "Produto inválido.");
}

/**
 * Mensagem push do Pub/Sub ({ message: { data: base64 } }). Devolve o que foi feito; erros de
 * rede/banco sobem para a função responder 500 e o Pub/Sub reenviar.
 */
export async function handleNotification(deps: PlayDeps, payload: unknown) {
  const data = (payload as { message?: { data?: string } })?.message?.data;
  if (typeof data !== "string") throw new PurchaseError(400, "Mensagem inválida.");
  let n: Record<string, Record<string, unknown> | string | undefined>;
  try {
    n = JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(data), (c) => c.charCodeAt(0))));
  } catch {
    throw new PurchaseError(400, "Mensagem inválida.");
  }
  if (n.packageName !== PLAY_PACKAGE) return "ignored";
  if (n.testNotification) return "test";
  const sub = n.subscriptionNotification as Record<string, unknown> | undefined;
  const voided = n.voidedPurchaseNotification as Record<string, unknown> | undefined;
  const oneTime = n.oneTimeProductNotification as Record<string, unknown> | undefined;
  if (voided?.purchaseToken) {
    await deps.rpc("revoke_play_purchase", { p_token: String(voided.purchaseToken) });
    return "revoked";
  }
  if (sub?.purchaseToken) {
    await syncSubscription(deps, String(sub.purchaseToken), null);
    return "subscription";
  }
  // 1 = ONE_TIME_PRODUCT_PURCHASED. Garante o Destaque mesmo se o app fechou antes de confirmar.
  if (oneTime?.purchaseToken && Number(oneTime.notificationType) === 1 && oneTime.sku === FEATURE_PRODUCT) {
    await syncFeature(deps, String(oneTime.purchaseToken), null);
    return "feature";
  }
  return "ignored";
}
