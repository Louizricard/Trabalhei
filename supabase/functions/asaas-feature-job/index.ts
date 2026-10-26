// Destaque de projeto (vaga patrocinada) por billing_products.job_feature.
// Body: { job_id, cpf_cnpj, billing_type?: "PIX" | "CREDIT_CARD", coupon_code? }
// Resposta: { granted: true, until } (cupom de 100%), Pix com QR Code ou a
// página segura do Asaas para cartão. O destaque é aplicado pelo webhook.
import {
  adminClient, asaas, getOrCreateCustomer, handle, HttpError, isoDate, json,
  pixQrCode, productDays, redeemPrice, requireUser, validateCpfCnpj,
} from "../_shared/common.ts";

Deno.serve(handle(async (req) => {
  const user = await requireUser(req);
  const body = await req.json().catch(() => ({}));
  const jobId = String(body.job_id ?? "");
  if (!jobId) throw new HttpError(400, "job_id é obrigatório.");
  const billingType = body.billing_type === "CREDIT_CARD" ? "CREDIT_CARD" : "PIX";

  const admin = adminClient();
  const { data: job } = await admin
    .from("jobs")
    .select("id, title, client_id, status, featured_until")
    .eq("id", jobId)
    .maybeSingle();
  if (!job || job.client_id !== user.id) throw new HttpError(404, "Vaga não encontrada.");
  if (job.status !== "open") throw new HttpError(409, "Só é possível destacar vagas abertas.");

  // Cobrança pendente recente desta vaga: reaproveita (sem cobrar de novo nem
  // gastar o cupom outra vez).
  const { data: pending } = await admin
    .from("job_featurings")
    .select("id, asaas_payment_id, amount")
    .eq("job_id", job.id)
    .eq("user_id", user.id)
    .eq("status", "pending")
    .gt("created_at", new Date(Date.now() - 24 * 3600_000).toISOString())
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (pending && !String(pending.asaas_payment_id).startsWith("coupon:")) {
    const existing = await asaas<{ invoiceUrl: string; status: string; billingType: string }>(
      `/payments/${pending.asaas_payment_id}`,
    );
    if (existing.status === "PENDING" && existing.billingType === billingType) {
      const reused = { payment_id: pending.asaas_payment_id, amount: Number(pending.amount), featuring_id: pending.id };
      return billingType === "PIX"
        ? json({ ...reused, pix: await pixQrCode(pending.asaas_payment_id), invoice_url: existing.invoiceUrl })
        : json({ ...reused, invoice_url: existing.invoiceUrl });
    }
  }

  const days = await productDays(admin, "job_feature");
  const featuringId = crypto.randomUUID();
  const quote = await redeemPrice(admin, user.id, "job_feature", body.coupon_code, `feature:${featuringId}`);

  // Cupom de 100%: aplica o destaque na hora, sem cobrança.
  if (quote.final_price === 0) {
    const base = job.featured_until && new Date(job.featured_until) > new Date()
      ? new Date(job.featured_until)
      : new Date();
    const until = new Date(base.getTime() + days * 86400_000).toISOString();
    const { error } = await admin.from("jobs").update({ featured_until: until }).eq("id", job.id);
    if (error) throw new HttpError(500, "Falha ao aplicar o destaque.", { cause: error });
    await admin.from("job_featurings").insert({
      id: featuringId, job_id: job.id, user_id: user.id,
      asaas_payment_id: `coupon:${quote.code}:${featuringId}`,
      days, amount: 0, status: "paid", paid_at: new Date().toISOString(),
    });
    return json({ granted: true, until });
  }

  let payment: { id: string; invoiceUrl: string };
  try {
    const cpfCnpj = validateCpfCnpj(body.cpf_cnpj);
    const customerId = await getOrCreateCustomer(admin, user, cpfCnpj);
    const due = new Date();
    due.setDate(due.getDate() + 1);
    payment = await asaas<{ id: string; invoiceUrl: string }>("/payments", {
      method: "POST",
      body: {
        customer: customerId,
        billingType,
        value: quote.final_price,
        dueDate: isoDate(due),
        description: `Destaque de projeto por ${days} dias: ${job.title}`,
        externalReference: `feature:${featuringId}`,
      },
    });
  } catch (e) {
    // Sem cobrança criada, o cupom volta a valer.
    await admin.rpc("release_coupon", { p_reference: `feature:${featuringId}` });
    throw e;
  }

  const { error } = await admin.from("job_featurings").insert({
    id: featuringId,
    job_id: job.id,
    user_id: user.id,
    asaas_payment_id: payment.id,
    days,
    amount: quote.final_price,
  });
  if (error) throw new HttpError(500, "Falha ao registrar o destaque.");

  const response = { payment_id: payment.id, amount: quote.final_price, featuring_id: featuringId };
  if (billingType === "PIX") {
    return json({ ...response, pix: await pixQrCode(payment.id), invoice_url: payment.invoiceUrl });
  }
  return json({ ...response, invoice_url: payment.invoiceUrl });
}));
