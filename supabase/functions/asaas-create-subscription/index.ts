// Cria a assinatura Pro do freelancer no Asaas.
// Body: { billing_type: "PIX" | "CREDIT_CARD", cpf_cnpj: string, coupon_code?: string }
// Resposta:
//   { granted: true, until }                 cupom de 100%: Pro liberado sem cobrança
//   { payment_id, amount, pix: {...} }       Pix: QR Code para pagar dentro do app
//   { payment_id, amount, invoice_url }      cartão: página segura do Asaas
// O preço vem de billing_products; o cupom vale para a primeira cobrança.
import {
  adminClient, asaas, getOrCreateCustomer, handle, HttpError, isoDate, json,
  pixQrCode, productDays, redeemPrice, requireUser, validateCpfCnpj,
} from "../_shared/common.ts";

Deno.serve(handle(async (req) => {
  const user = await requireUser(req);
  const body = await req.json().catch(() => ({}));
  const billingType = body.billing_type;
  if (billingType !== "PIX" && billingType !== "CREDIT_CARD") {
    throw new HttpError(400, "Forma de pagamento inválida.");
  }

  const admin = adminClient();

  // Evita assinaturas duplicadas.
  const { data: current } = await admin
    .from("subscriptions")
    .select("id, status, billing_type, asaas_subscription_id")
    .eq("user_id", user.id)
    .in("status", ["pending", "active", "overdue"])
    .maybeSingle();
  if (current?.status === "active") {
    throw new HttpError(409, "Você já possui uma assinatura ativa.");
  }

  let subscriptionId = current?.asaas_subscription_id as string | undefined;
  const couponCode = typeof body.coupon_code === "string" ? body.coupon_code.trim().toUpperCase() : "";

  if (subscriptionId && current?.status === "pending") {
    // Cupom já aplicado a esta assinatura pendente: segue com ela.
    const { data: used } = couponCode
      ? await admin.from("coupon_redemptions").select("final_price")
        .eq("user_id", user.id).eq("code", couponCode)
        .like("reference", `sub:${current.id}%`).maybeSingle()
      : { data: null };
    // Outra forma de pagamento ou cupom novo: recomeça a assinatura.
    if (current.billing_type !== billingType || (couponCode && !used)) {
      await asaas(`/subscriptions/${subscriptionId}`, { method: "DELETE" });
      await admin.from("subscriptions").update({ status: "cancelled" }).eq("id", current.id);
      subscriptionId = undefined;
    }
  }

  let amount: number | undefined;
  if (!subscriptionId) {
    // Referência única por tentativa (o uso do cupom é desfeito por ela).
    const subscriptionRowId = crypto.randomUUID();
    const reference = `sub:${subscriptionRowId}`;
    const quote = await redeemPrice(admin, user.id, "pro_monthly", couponCode, reference);
    if (quote.final_price === 0) {
      const days = await productDays(admin, "pro_monthly");
      const { data: until, error } = await admin.rpc("grant_pro", {
        p_user: user.id,
        p_days: days,
        p_reason: `Cupom ${quote.code} aplicado.`,
      });
      if (error) throw new HttpError(500, "Falha ao liberar o Pro.", { cause: error });
      return json({ granted: true, until });
    }

    let sub: { id: string };
    try {
      const cpfCnpj = validateCpfCnpj(body.cpf_cnpj);
      const customerId = await getOrCreateCustomer(admin, user, cpfCnpj);
      sub = await asaas<{ id: string }>("/subscriptions", {
        method: "POST",
        body: {
          customer: customerId,
          billingType,
          value: quote.price,
          nextDueDate: isoDate(new Date()),
          cycle: "MONTHLY",
          description: "Trabalhei Pro",
          externalReference: `sub:${user.id}`,
        },
      });
    } catch (e) {
      // Sem assinatura criada, o cupom volta a valer.
      await admin.rpc("release_coupon", { p_reference: reference });
      throw e;
    }
    subscriptionId = sub.id;
    const { error } = await admin.from("subscriptions").insert({
      id: subscriptionRowId,
      user_id: user.id,
      asaas_subscription_id: sub.id,
      billing_type: billingType,
      status: "pending",
    });
    if (error) throw new HttpError(500, "Falha ao registrar assinatura.");
    if (quote.final_price < quote.price) amount = quote.final_price;
  }

  // Primeira cobrança, gerada pelo Asaas. Com cupom, só ela recebe o desconto.
  const payments = await asaas<{ data: { id: string; value: number; invoiceUrl?: string }[] }>(
    `/subscriptions/${subscriptionId}/payments`,
  );
  const first = payments.data?.[0];
  if (!first) throw new HttpError(502, "Cobrança ainda não disponível. Tente novamente em instantes.");
  if (amount !== undefined && amount !== first.value) {
    await asaas(`/payments/${first.id}`, { method: "POST", body: { value: amount } });
  }

  const response = { payment_id: first.id, amount: amount ?? first.value };
  if (billingType === "PIX") {
    return json({ ...response, pix: await pixQrCode(first.id), invoice_url: first.invoiceUrl });
  }
  // Cartão: a página segura do Asaas (o app nunca toca em dados de cartão).
  if (!first.invoiceUrl) throw new HttpError(502, "Link de pagamento indisponível.");
  return json({ ...response, invoice_url: first.invoiceUrl });
}));
