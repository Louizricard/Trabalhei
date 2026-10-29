import { HttpError, isoDate } from "./common.ts";
import type { Body, Checkout } from "./checkout.ts";

const payable = (p: Body) =>
  ["PENDING", "OVERDUE"].includes(String(p.status)) && !p.deleted;

async function checkPendingCoupon(c: Checkout, reference: string) {
  const used = await c.read("coupon_redemptions", {
    user_id: c.user.id,
    reference,
  });
  if ((used?.code ?? "") !== c.intent.coupon_code) {
    throw new HttpError(
      409,
      "Já existe uma cobrança pendente. Retome com o cupom original. Para trocar o cupom, cancele a assinatura pendente ou solicite o cancelamento do destaque ao suporte.",
    );
  }
  return used;
}

async function adjustPayment(
  c: Checkout,
  payment: Body,
  amount = Number(payment.value),
) {
  if (!payable(payment)) {
    throw new HttpError(
      409,
      "Esta cobrança não está mais pendente. Aguarde a confirmação ou atualize a tela.",
    );
  }
  if (
    payment.billingType !== c.intent.billing_type ||
    Number(payment.value) !== amount
  ) {
    // Repetir PUT com os mesmos valores não cria outra cobrança.
    await c.rpc("reserve_billing_step", { p_key: `${c.intent.id}:update` });
    payment = await c.provider.call<Body>(`/payments/${payment.id}`, "PUT", {
      billingType: c.intent.billing_type,
      value: amount,
      dueDate: payment.dueDate,
    });
  }
  return payment;
}

export async function proCheckout(c: Checkout, body: Body): Promise<Body> {
  const current = await c.read("subscriptions", {
    user_id: c.user.id,
    status: ["pending", "active", "overdue"],
  });
  if (current?.status === "active") {
    throw new HttpError(409, "Você já possui uma assinatura ativa.");
  }
  if (!current) return await newSubscription(c, body);
  const used = await checkPendingCoupon(c, `sub:${current.id}`);
  const priced = await c.read("billing_checkouts", { id: current.id });
  const amount = priced?.quote
    ? Number((priced.quote as Body).final_price)
    : used
    ? Number(used.final_price)
    : undefined;
  return await subscriptionPayment(c, current, amount);
}

async function newSubscription(c: Checkout, body: Body) {
  const priced = await c.price();
  if (priced.result?.granted) return priced.result;
  const customer = await c.provider.customer(body.cpf_cnpj);
  const id = await c.provider.create("/subscriptions", {
    customer,
    billingType: c.intent.billing_type,
    value: priced.quote.price,
    nextDueDate: isoDate(new Date()),
    cycle: "MONTHLY",
    description: "Trabalhei Pro",
    externalReference: `sub:${c.intent.id}`,
  }, `${c.intent.id}:subscription`);
  await c.rpc("link_billing_checkout", { p_provider: id });
  const current = {
    id: c.intent.id,
    asaas_subscription_id: id,
    billing_type: c.intent.billing_type,
  };
  return await subscriptionPayment(
    c,
    current,
    Number(priced.quote.final_price),
  );
}

async function subscriptionPayment(
  c: Checkout,
  current: Body,
  amount?: number,
) {
  const id = String(current.asaas_subscription_id);
  if (current.billing_type !== c.intent.billing_type) {
    await c.rpc("reserve_billing_step", { p_key: `${c.intent.id}:method` });
    await c.provider.call(`/subscriptions/${id}`, "PUT", {
      billingType: c.intent.billing_type,
      updatePendingPayments: true,
    });
    await c.update("subscriptions", String(current.id), {
      billing_type: c.intent.billing_type,
    });
  }
  const list = await c.provider.call<{ data: Body[]; hasMore?: boolean }>(
    `/subscriptions/${id}/payments?limit=100`,
  );
  const pending = list.data.filter(payable).sort((a, b) =>
    String(a.dueDate).localeCompare(String(b.dueDate))
  );
  if (!pending.length || list.hasMore) {
    throw new HttpError(
      503,
      "Cobrança ainda indisponível. Retome esta tentativa em instantes.",
    );
  }
  const first =
    list.data.filter((p) => !p.deleted).sort((a, b) =>
      String(a.dueDate).localeCompare(String(b.dueDate))
    )[0];
  const payment = await adjustPayment(
    c,
    pending[0],
    first?.id === pending[0].id ? amount : undefined,
  );
  await c.finish({ payment_id: payment.id }, id);
  return await c.provider.response(payment);
}

export async function featureCheckout(c: Checkout, body: Body): Promise<Body> {
  if (c.intent.result?.payment_id) {
    const completed = await c.read("job_featurings", {
      asaas_payment_id: c.intent.result.payment_id,
      user_id: c.user.id,
    });
    if (completed?.status === "paid") {
      return { granted: true, payment_id: c.intent.result.payment_id };
    }
  }
  const current = await c.read("job_featurings", {
    job_id: c.intent.job_id,
    user_id: c.user.id,
    status: "pending",
  });
  if (current) {
    await checkPendingCoupon(c, `feature:${current.id}`);
    const payment = await adjustPayment(
      c,
      await c.provider.call<Body>(`/payments/${current.asaas_payment_id}`),
    );
    await c.finish({ payment_id: payment.id });
    return await c.provider.response(payment, String(current.id));
  }
  return await newFeature(c, body);
}

async function newFeature(c: Checkout, body: Body) {
  const { quote, result } = await c.price();
  if (result?.granted) return result;
  const job = await c.read("jobs", {
    id: c.intent.job_id,
    client_id: c.user.id,
    status: "open",
  });
  if (!job) throw new HttpError(409, "Vaga indisponível para destaque.");
  const customer = await c.provider.customer(body.cpf_cnpj);
  const due = new Date(Date.now() + 86400_000);
  const id = await c.provider.create("/payments", {
    customer,
    billingType: c.intent.billing_type,
    value: quote.final_price,
    dueDate: isoDate(due),
    description: `Destaque de projeto por ${quote.days} dias: ${job.title}`,
    externalReference: `feature:${c.intent.id}`,
  }, `${c.intent.id}:payment`);
  await c.rpc("link_billing_checkout", { p_provider: id });
  await c.finish({ payment_id: id });
  return await c.provider.response(
    await c.provider.call<Body>(`/payments/${id}`),
    c.intent.id,
  );
}
