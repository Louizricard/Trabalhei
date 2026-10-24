// Utilitários compartilhados pelas Edge Functions de cobrança (Asaas).
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

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
  constructor(public status: number, message: string) {
    super(message);
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
    throw new HttpError(502, `Falha no provedor de pagamento: ${detail}`);
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

export function handle(fn: (req: Request) => Promise<Response>) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    try {
      return await fn(req);
    } catch (e) {
      if (e instanceof HttpError) return json({ error: e.message }, e.status);
      console.error("[unhandled]", e);
      return json({ error: "Erro interno." }, 500);
    }
  };
}
