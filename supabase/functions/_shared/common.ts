// Utilitários compartilhados pelas Edge Functions de cobrança (Asaas).
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import * as Sentry from "npm:@sentry/deno@11.6.0";

// Sem SENTRY_DSN, os erros só vão para os logs da função.
const sentryDsn = Deno.env.get("SENTRY_DSN");
if (sentryDsn) {
  // As integrações padrão compartilham contexto entre requisições no Edge Runtime;
  // cada erro leva o próprio contexto via withScope (guia de Sentry do Supabase).
  Sentry.init({
    dsn: sentryDsn,
    defaultIntegrations: false,
    environment: Deno.env.get("SENTRY_ENVIRONMENT") ?? "production",
  });
}

/** Registra o erro no log e, se configurado, no Sentry, marcado com o nome da função. */
export async function reportError(
  functionName: string,
  error: unknown,
  extra: Record<string, unknown> = {},
): Promise<void> {
  console.error(`[${functionName}]`, error, extra);
  if (!sentryDsn) return;
  Sentry.withScope((scope) => {
    scope.setTag("function", functionName);
    scope.setExtras(extra);
    Sentry.captureException(error);
  });
  await Sentry.flush(2000);
}

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export class HttpError extends Error {
  constructor(public status: number, message: string, options?: { cause?: unknown }) {
    super(message, options);
  }
}

export function env(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new HttpError(500, `Variável de ambiente ausente: ${name}`);
  return value;
}

/** Cliente com privilégios totais (service_role). Nunca expor ao app. */
export function adminClient(): SupabaseClient {
  return createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { persistSession: false },
  });
}

/** Resolve o usuário autenticado a partir do JWT da requisição. */
export async function requireUser(req: Request) {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) throw new HttpError(401, "Não autenticado.");
  const userClient = createClient(env("SUPABASE_URL"), env("SUPABASE_ANON_KEY"), {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data, error } = await userClient.auth.getUser();
  if (error || !data.user) throw new HttpError(401, "Sessão inválida.");
  return data.user;
}

/** Chamada à API do Asaas (sandbox por padrão; defina ASAAS_BASE_URL em produção). */
export async function asaas<T = Record<string, unknown>>(
  path: string,
  init: { method?: string; body?: unknown } = {},
): Promise<T> {
  const base = Deno.env.get("ASAAS_BASE_URL") ?? "https://api-sandbox.asaas.com/v3";
  const res = await fetch(`${base}${path}`, {
    method: init.method ?? "GET",
    headers: {
      "Content-Type": "application/json",
      access_token: env("ASAAS_API_KEY"),
      "User-Agent": "trabalhei",
    },
    body: init.body ? JSON.stringify(init.body) : undefined,
  });
  const text = await res.text();
  const data = text ? JSON.parse(text) : {};
  if (!res.ok) {
    const detail = data?.errors?.[0]?.description ?? `HTTP ${res.status}`;
    console.error("[asaas]", path, res.status, text);
    throw new HttpError(502, `Falha no provedor de pagamento: ${detail}`, {
      cause: new Error(`Asaas ${init.method ?? "GET"} ${path}: HTTP ${res.status} - ${detail}`),
    });
  }
  return data as T;
}

export function validateCpfCnpj(raw: unknown): string {
  const digits = String(raw ?? "").replace(/\D/g, "");
  if (digits.length !== 11 && digits.length !== 14) {
    throw new HttpError(400, "CPF/CNPJ inválido.");
  }
  return digits;
}

export function isoDate(d: Date): string {
  return d.toISOString().slice(0, 10);
}

/** Encontra ou cria o cliente do usuário no Asaas. */
export async function getOrCreateCustomer(
  admin: SupabaseClient,
  user: { id: string; email?: string | null },
  cpfCnpj: string,
): Promise<string> {
  const { data: existing } = await admin
    .from("billing_customers")
    .select("asaas_customer_id")
    .eq("user_id", user.id)
    .maybeSingle();
  if (existing) return existing.asaas_customer_id as string;

  const { data: profile } = await admin
    .from("profiles")
    .select("full_name")
    .eq("id", user.id)
    .single();

  const customer = await asaas<{ id: string }>("/customers", {
    method: "POST",
    body: {
      name: profile?.full_name ?? "Cliente Trabalhei",
      email: user.email,
      cpfCnpj,
      externalReference: user.id,
    },
  });
  const { error } = await admin
    .from("billing_customers")
    .insert({ user_id: user.id, asaas_customer_id: customer.id });
  if (error) throw new HttpError(500, "Falha ao registrar cliente de cobrança.");
  return customer.id;
}

/**
 * Cancela no Asaas a assinatura em aberto do usuário, se houver.
 * O plano segue ativo até o fim do período já pago. Retorna false se não havia assinatura.
 */
export async function cancelOpenSubscription(admin: SupabaseClient, userId: string): Promise<boolean> {
  const { data: sub } = await admin
    .from("subscriptions")
    .select("id, asaas_subscription_id")
    .eq("user_id", userId)
    .in("status", ["pending", "active", "overdue"])
    .maybeSingle();
  if (!sub) return false;

  await asaas(`/subscriptions/${sub.asaas_subscription_id}`, { method: "DELETE" });
  await admin.from("subscriptions").update({ status: "cancelled" }).eq("id", sub.id);
  return true;
}

// ---------------------------------------------------------------- Preços e cupons
// Preços ficam em public.billing_products e cupons em public.coupons (ver
// docs/monetizacao.md). Nada de preço fixo no código.

const COUPON_ERRORS: Record<string, string> = {
  COUPON_INVALID: "Cupom inválido.",
  COUPON_NOT_FOR_PRODUCT: "Este cupom não vale para este produto.",
  COUPON_EXPIRED: "Este cupom expirou ou ainda não começou a valer.",
  COUPON_EXHAUSTED: "Este cupom já atingiu o limite de usos.",
  COUPON_ALREADY_USED: "Você já usou este cupom.",
  PRODUCT_UNAVAILABLE: "Este produto não está disponível no momento.",
};

export interface Quote {
  price: number;
  final_price: number;
  discount: number;
  code?: string;
}

/**
 * Preço final do produto para o usuário. Com cupom, registra o uso de forma
 * atômica (o limite do cupom não estoura com compras simultâneas).
 */
export async function redeemPrice(
  admin: SupabaseClient,
  userId: string,
  product: "pro_monthly" | "job_feature",
  couponCode: unknown,
  reference: string,
): Promise<Quote> {
  const code = typeof couponCode === "string" ? couponCode.trim() : "";
  const { data, error } = await admin.rpc("redeem_coupon", {
    p_user: userId,
    p_product: product,
    p_code: code || null,
    p_reference: reference,
  });
  if (error) {
    const known = Object.keys(COUPON_ERRORS).find((k) => error.message?.includes(k));
    if (known) throw new HttpError(400, COUPON_ERRORS[known]);
    throw new HttpError(500, "Falha ao calcular o preço.", { cause: error });
  }
  const q = data as Record<string, unknown>;
  return {
    price: Number(q.price),
    final_price: Number(q.final_price),
    discount: Number(q.discount ?? 0),
    code: (q.code as string | undefined) ?? undefined,
  };
}

/** Prazo (dias) do produto em billing_products. */
export async function productDays(admin: SupabaseClient, product: string): Promise<number> {
  const { data } = await admin.from("billing_products").select("period_days").eq("code", product).maybeSingle();
  return Number(data?.period_days ?? (product === "job_feature" ? 7 : 30));
}

/** QR Code Pix de uma cobrança, para pagar sem sair do app. */
export async function pixQrCode(paymentId: string) {
  const qr = await asaas<{ encodedImage: string; payload: string; expirationDate?: string }>(
    `/payments/${paymentId}/pixQrCode`,
  );
  return { image_base64: qr.encodedImage, payload: qr.payload, expires_at: qr.expirationDate ?? null };
}

/** Trata OPTIONS e erros. Falhas 5xx (do servidor ou do Asaas) vão para reportError. */
export function handle(fn: (req: Request) => Promise<Response>) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    try {
      return await fn(req);
    } catch (e) {
      const functionName = new URL(req.url).pathname.split("/").filter(Boolean).pop() ?? "unknown";
      if (e instanceof HttpError) {
        if (e.status >= 500) await reportError(functionName, e.cause ?? e, { status: e.status });
        return json({ error: e.message }, e.status);
      }
      await reportError(functionName, e);
      return json({ error: "Erro interno." }, 500);
    }
  };
}
