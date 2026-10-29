import {
  adminClient,
  handle,
  HttpError,
  json,
  requireUser,
  validateCpfCnpj,
} from "./common.ts";
import { CheckoutProvider } from "./checkout_provider.ts";

export type Admin = ReturnType<typeof adminClient>;
export type Body = Record<string, unknown>;
export interface Intent {
  id: string;
  user_id: string;
  product: string;
  job_id: string | null;
  billing_type: string;
  coupon_code: string;
  result?: Body;
}
export class Checkout {
  readonly provider: CheckoutProvider;
  constructor(
    readonly admin: Admin,
    readonly intent: Intent,
    readonly token: string,
    readonly user: { id: string; email?: string | null },
    request?: typeof fetch,
  ) {
    this.provider = new CheckoutProvider(this, request);
  }

  async rpc<T = unknown>(name: string, data: Body = {}): Promise<T> {
    const { data: result, error } = await this.admin.rpc(name, {
      p_id: this.intent.id,
      p_token: this.token,
      ...data,
    });
    if (error) throw checkoutError(error);
    return result as T;
  }

  async price() {
    return await this.rpc<{ quote: Body; result?: Body }>(
      "price_billing_checkout",
    );
  }

  async finish(result: Body, subscriptionId?: string) {
    // QR Code e URLs ficam fora do diário; uma nova leitura atualiza sua validade.
    await this.rpc("finish_billing_checkout", {
      p_result: {
        payment_id: result.payment_id,
        subscription_id: subscriptionId,
      },
    });
    return result;
  }

  async read<T extends Body = Body>(
    table: string,
    filters: Body,
    columns = "*",
  ): Promise<T | null> {
    let query = this.admin.from(table).select(columns);
    for (const [column, value] of Object.entries(filters)) {
      query = Array.isArray(value)
        ? query.in(column, value)
        : query.eq(column, value);
    }
    const { data, error } = await query.maybeSingle();
    if (error) throw checkoutError(error);
    return data as T | null;
  }

  async update(table: string, id: string, data: Body) {
    const { error } = await this.admin.from(table).update(data).eq("id", id);
    if (error) throw checkoutError(error);
  }
}

export function checkoutError(error: { message: string }) {
  if (/CHECKOUT_BUSY|CHECKOUT_LEASE_LOST/.test(error.message)) {
    return new HttpError(
      409,
      "Um pagamento já está sendo preparado. Aguarde e tente novamente.",
    );
  }
  if (
    /CHECKOUT_RECOVERY_REQUIRED|CHECKOUT_REQUEST_CONFLICT/.test(error.message)
  ) {
    return new HttpError(
      409,
      "Retome a tentativa anterior com a mesma forma de pagamento e cupom.",
    );
  }
  if (/JOB_NOT_OPEN/.test(error.message)) {
    return new HttpError(409, "Só é possível destacar sua vaga aberta.");
  }
  if (/COUPON_|PRODUCT_UNAVAILABLE/.test(error.message)) {
    return new HttpError(
      400,
      "Cupom inválido, indisponível ou já utilizado. Confira o cupom.",
    );
  }
  return new HttpError(500, "Falha ao registrar o pagamento.", {
    cause: new Error("Checkout database operation failed"),
  });
}

export async function runCheckout(
  admin: Admin,
  user: { id: string; email?: string | null },
  product: string,
  body: Body,
  run: (c: Checkout, body: Body) => Promise<Body>,
  request?: typeof fetch,
) {
  const c = await claimCheckout(admin, user, product, body, request);
  try {
    if (c.intent.result?.granted) return c.intent.result;
    return await run(c, body);
  } finally {
    const { error: releaseError } = await admin.rpc(
      "release_billing_checkout",
      {
        p_id: c.intent.id,
        p_token: c.token,
      },
    );
    if (releaseError) console.error("[checkout] lease release failed");
  }
}

function validateBody(body: Body, product: string) {
  const type = body.billing_type ?? "PIX";
  if (type !== "PIX" && type !== "CREDIT_CARD") {
    throw new HttpError(400, "Forma de pagamento inválida.");
  }
  validateCpfCnpj(body.cpf_cnpj);
  const uuid =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (body.request_id != null && !uuid.test(String(body.request_id))) {
    throw new HttpError(400, "Identificador de pagamento inválido.");
  }
  if (product === "job_feature" && !uuid.test(String(body.job_id))) {
    throw new HttpError(400, "Vaga inválida.");
  }
  return type;
}

async function claimCheckout(
  admin: Admin,
  user: { id: string; email?: string | null },
  product: string,
  body: Body,
  request?: typeof fetch,
) {
  const type = validateBody(body, product);
  const { data, error } = await admin.rpc("claim_billing_checkout", {
    p_user: user.id,
    p_product: product,
    p_job: product === "job_feature" ? body.job_id : null,
    p_billing_type: type,
    p_coupon: typeof body.coupon_code === "string" ? body.coupon_code : "",
    p_request: body.request_id ?? null,
  });
  if (error) throw checkoutError(error);
  return new Checkout(admin, data.checkout, data.token, user, request);
}

export function checkoutHandler(
  product: string,
  run: (c: Checkout, body: Body) => Promise<Body>,
) {
  return handle(async (req) => {
    if (req.method !== "POST") {
      throw new HttpError(405, "Método não permitido.");
    }
    const user = await requireUser(req);
    const body = await req.json().catch(() => ({}));
    return json(await runCheckout(adminClient(), user, product, body, run));
  });
}
