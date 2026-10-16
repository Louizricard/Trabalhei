// Cria a assinatura Pro do freelancer no Asaas e devolve o link da fatura.
// Body: { billing_type: "PIX" | "CREDIT_CARD", cpf_cnpj: string }
import {
  adminClient, asaas, getOrCreateCustomer, handle, HttpError, isoDate, json,
  requireUser, validateCpfCnpj,
} from "../_shared/common.ts";

Deno.serve(handle(async (req) => {
  const user = await requireUser(req);
  const body = await req.json().catch(() => ({}));
  const billingType = body.billing_type;
  if (billingType !== "PIX" && billingType !== "CREDIT_CARD") {
    throw new HttpError(400, "Forma de pagamento inválida.");
  }
  const cpfCnpj = validateCpfCnpj(body.cpf_cnpj);

  const admin = adminClient();

  // Evita assinaturas duplicadas.
  const { data: current } = await admin
    .from("subscriptions")
    .select("id, status, asaas_subscription_id")
    .eq("user_id", user.id)
    .in("status", ["pending", "active", "overdue"])
    .maybeSingle();
  if (current?.status === "active") {
    throw new HttpError(409, "Você já possui uma assinatura ativa.");
  }

  let subscriptionId = current?.asaas_subscription_id as string | undefined;
  if (!subscriptionId) {
    const customerId = await getOrCreateCustomer(admin, user, cpfCnpj);
    const price = Number(Deno.env.get("PRO_PRICE") ?? "29.90");
    const sub = await asaas<{ id: string }>("/subscriptions", {
      method: "POST",
      body: {
        customer: customerId,
        billingType,
        value: price,
        nextDueDate: isoDate(new Date()),
        cycle: "MONTHLY",
        description: "FreelanceFlow Pro",
        externalReference: `sub:${user.id}`,
      },
    });
    subscriptionId = sub.id;
    const { error } = await admin.from("subscriptions").insert({
      user_id: user.id,
      asaas_subscription_id: sub.id,
      billing_type: billingType,
      status: "pending",
    });
    if (error) throw new HttpError(500, "Falha ao registrar assinatura.");
  }

  // A primeira cobrança é gerada pelo Asaas; usamos a fatura hospedada
  // (a plataforma nunca toca em dados de cartão).
  const payments = await asaas<{ data: { invoiceUrl?: string }[] }>(
    `/subscriptions/${subscriptionId}/payments`,
  );
  const invoiceUrl = payments.data?.[0]?.invoiceUrl;
  if (!invoiceUrl) throw new HttpError(502, "Cobrança ainda não disponível. Tente novamente em instantes.");
  return json({ invoice_url: invoiceUrl });
}));
