// Cliente mínimo da Google Play Developer API (androidpublisher v3) com conta de serviço.
// Segredo GOOGLE_PLAY_SERVICE_ACCOUNT: o JSON da chave da conta de serviço, com acesso ao app no
// Play Console (ver docs/play-billing.md). Nenhum valor do Google vem do app sem ser conferido aqui.

export const PLAY_PACKAGE = "com.trabalhei.app";
export const PRO_PRODUCT = "pro_monthly";
export const FEATURE_PRODUCT = "job_feature";

const API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications";
const SCOPE = "https://www.googleapis.com/auth/androidpublisher";

export class PlayApiError extends Error {
  constructor(public status: number, path: string) {
    super(`Google Play HTTP ${status} em ${path}`);
  }
}

/** Estado da assinatura no Trabalhei (tabela play_purchases). */
export type PlayState = "pending" | "active" | "cancelled" | "expired";

export interface PlaySubscription {
  state: PlayState;
  productId: string | null;
  expiresAt: string | null;
  accountId: string | null;
  orderId: string | null;
  needsAck: boolean;
}

export interface PlayProduct {
  /** 0 comprado, 1 cancelado, 2 pendente (purchases.products). */
  purchaseState: number;
  accountId: string | null;
  profileId: string | null;
  orderId: string | null;
  consumed: boolean;
}

export interface GooglePlay {
  subscription(token: string): Promise<PlaySubscription>;
  acknowledgeSubscription(productId: string, token: string): Promise<void>;
  cancelSubscription(productId: string, token: string): Promise<void>;
  product(productId: string, token: string): Promise<PlayProduct>;
  consumeProduct(productId: string, token: string): Promise<void>;
}

/** Converte subscriptionState do subscriptionsv2 para o estado do Trabalhei. */
export function mapSubscriptionState(googleState: string): PlayState {
  switch (googleState) {
    case "SUBSCRIPTION_STATE_ACTIVE":
    case "SUBSCRIPTION_STATE_IN_GRACE_PERIOD":
      return "active";
    case "SUBSCRIPTION_STATE_CANCELED":
      return "cancelled";
    case "SUBSCRIPTION_STATE_PENDING":
      return "pending";
    default:
      // ON_HOLD, PAUSED, EXPIRED, PENDING_PURCHASE_CANCELED e estados desconhecidos: sem benefício.
      return "expired";
  }
}

// deno-lint-ignore no-explicit-any
export function parseSubscription(body: any): PlaySubscription {
  const item = Array.isArray(body?.lineItems) ? body.lineItems[0] : undefined;
  return {
    state: mapSubscriptionState(String(body?.subscriptionState ?? "")),
    productId: item?.productId ?? null,
    expiresAt: item?.expiryTime ?? null,
    accountId: body?.externalAccountIdentifiers?.obfuscatedExternalAccountId ?? null,
    orderId: body?.latestOrderId ?? item?.latestSuccessfulOrderId ?? null,
    needsAck: body?.acknowledgementState === "ACKNOWLEDGEMENT_STATE_PENDING",
  };
}

// deno-lint-ignore no-explicit-any
export function parseProduct(body: any): PlayProduct {
  return {
    purchaseState: Number(body?.purchaseState ?? -1),
    accountId: body?.obfuscatedExternalAccountId ?? null,
    profileId: body?.obfuscatedExternalProfileId ?? null,
    orderId: body?.orderId ?? null,
    consumed: Number(body?.consumptionState ?? 0) === 1,
  };
}

function base64url(data: Uint8Array | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function accessToken(credentials: { client_email: string; private_key: string; token_uri?: string }, request: typeof fetch) {
  const now = Math.floor(Date.now() / 1000);
  const tokenUri = credentials.token_uri ?? "https://oauth2.googleapis.com/token";
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64url(JSON.stringify({
    iss: credentials.client_email,
    scope: SCOPE,
    aud: tokenUri,
    iat: now,
    exp: now + 3600,
  }));
  const pem = credentials.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claims}`)),
  );
  const res = await request(tokenUri, {
    method: "POST",
    signal: AbortSignal.timeout(15_000),
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${header}.${claims}.${base64url(signature)}`,
    }),
  });
  if (!res.ok) throw new PlayApiError(res.status, "oauth");
  const data = await res.json();
  return { token: String(data.access_token), expires: Date.now() + (Number(data.expires_in ?? 3600) - 60) * 1000 };
}

/** Cliente real. `serviceAccountJson` é o conteúdo do segredo GOOGLE_PLAY_SERVICE_ACCOUNT. */
export function googlePlay(serviceAccountJson: string, request: typeof fetch = fetch): GooglePlay {
  const credentials = JSON.parse(serviceAccountJson);
  let cached: { token: string; expires: number } | null = null;

  async function call(path: string, method = "GET", body?: unknown) {
    if (!cached || cached.expires < Date.now()) cached = await accessToken(credentials, request);
    const res = await request(`${API}/${PLAY_PACKAGE}/${path}`, {
      method,
      signal: AbortSignal.timeout(20_000),
      headers: { Authorization: `Bearer ${cached.token}`, "Content-Type": "application/json" },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await res.text();
    if (!res.ok) throw new PlayApiError(res.status, path.split("/tokens/")[0]);
    return text ? JSON.parse(text) : {};
  }

  const enc = encodeURIComponent;
  return {
    subscription: async (token) =>
      parseSubscription(await call(`purchases/subscriptionsv2/tokens/${enc(token)}`)),
    acknowledgeSubscription: async (productId, token) => {
      await call(`purchases/subscriptions/${enc(productId)}/tokens/${enc(token)}:acknowledge`, "POST", {});
    },
    cancelSubscription: async (productId, token) => {
      await call(`purchases/subscriptions/${enc(productId)}/tokens/${enc(token)}:cancel`, "POST");
    },
    product: async (productId, token) =>
      parseProduct(await call(`purchases/products/${enc(productId)}/tokens/${enc(token)}`)),
    consumeProduct: async (productId, token) => {
      await call(`purchases/products/${enc(productId)}/tokens/${enc(token)}:consume`, "POST");
    },
  };
}
