import { env, HttpError, validateCpfCnpj } from "./common.ts";
import type { Body, Checkout } from "./checkout.ts";

interface Remote extends Body {
  id: string;
  externalReference?: string;
}
class ProviderRejection extends HttpError {}
export class CheckoutProvider {
  constructor(
    readonly checkout: Checkout,
    readonly request: typeof fetch = fetch,
  ) {}

  async call<T = Remote>(
    path: string,
    method = "GET",
    body?: Body,
  ): Promise<T> {
    const base = Deno.env.get("ASAAS_BASE_URL") ??
      "https://api-sandbox.asaas.com/v3";
    const response = await this.request(`${base}${path}`, {
      method,
      signal: AbortSignal.timeout(20_000),
      headers: {
        access_token: env("ASAAS_API_KEY"),
        "Content-Type": "application/json",
        "User-Agent": "trabalhei",
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    if (!response.ok) {
      if ([400, 422].includes(response.status)) {
        throw new ProviderRejection(
          400,
          "Dados recusados pelo provedor. Confira o CPF/CNPJ e os dados do cadastro.",
        );
      }
      // Não registra a resposta bruta: o provedor pode repetir dados pessoais.
      throw new HttpError(
        502,
        "O provedor de pagamento está indisponível. Retome esta tentativa em instantes.",
      );
    }
    return await response.json() as T;
  }

  async create(path: string, body: Body, key: string): Promise<string> {
    const c = this.checkout;
    const { fresh, step } = await c.rpc<{
      fresh: boolean;
      step: { id: string; provider_id: string | null };
    }>("reserve_billing_step", { p_key: key });
    if (step.provider_id) return step.provider_id;
    let remote: Remote;
    if (fresh) {
      try {
        remote = await this.call<Remote>(path, "POST", body);
      } catch (error) {
        if (error instanceof ProviderRejection) {
          await c.rpc("reject_billing_step", { p_step: step.id });
        }
        throw error;
      }
    } else {
      remote = await this.reconcile(path, String(body.externalReference));
    }
    const { error } = await c.admin.rpc("record_billing_step", {
      p_step: step.id,
      p_provider: remote.id,
    });
    if (error) {
      throw new HttpError(
        503,
        "Pagamento em conciliação. Retome esta mesma tentativa.",
      );
    }
    return remote.id;
  }

  async reconcile(path: string, reference: string): Promise<Remote> {
    const list = await this.call<{ data: Remote[]; hasMore?: boolean }>(
      `${path}?externalReference=${encodeURIComponent(reference)}&limit=100${
        path === "/subscriptions" ? "&includeDeleted=true" : ""
      }`,
    );
    const matching = list.data.filter((item) =>
      item.externalReference === reference
    );
    if (list.hasMore || matching.length !== 1) {
      throw new HttpError(
        503,
        "Pagamento em conciliação. Não será criada outra cobrança. Tente novamente ou contate o suporte.",
      );
    }
    return matching[0];
  }

  async customer(cpf: unknown): Promise<string> {
    const c = this.checkout;
    const existing = await c.read("billing_customers", { user_id: c.user.id });
    if (existing) return String(existing.asaas_customer_id);
    const profile = await c.read("profiles", { id: c.user.id }, "full_name");
    const id = await this.create("/customers", {
      name: profile?.full_name ?? "Cliente Trabalhei",
      email: c.user.email,
      cpfCnpj: validateCpfCnpj(cpf),
      externalReference: c.user.id,
    }, "customer");
    // A lease vale para todos os produtos do usuário; o diário do cliente também.
    await c.rpc("reserve_billing_step", { p_key: "customer" });
    const { error } = await c.admin.from("billing_customers").upsert({
      user_id: c.user.id,
      asaas_customer_id: id,
    }, { onConflict: "user_id", ignoreDuplicates: true });
    if (error) {
      throw new HttpError(500, "Falha ao associar o cliente de cobrança.");
    }
    return id;
  }

  async response(payment: Body, featuringId?: string): Promise<Body> {
    const c = this.checkout;
    const result: Body = {
      payment_id: payment.id,
      amount: payment.value,
      featuring_id: featuringId,
      invoice_url: payment.invoiceUrl,
    };
    if (c.intent.billing_type === "PIX") {
      const qr = await this.call<Body>(`/payments/${payment.id}/pixQrCode`);
      if (!qr.payload || !qr.encodedImage) {
        throw new HttpError(
          502,
          "Pix ainda indisponível. Retome a cobrança em instantes.",
        );
      }
      result.pix = {
        image_base64: qr.encodedImage,
        payload: qr.payload,
        expires_at: qr.expirationDate ?? null,
      };
    } else if (!payment.invoiceUrl) {
      throw new HttpError(
        502,
        "Link de pagamento indisponível. Retome a cobrança em instantes.",
      );
    }
    return result;
  }
}
