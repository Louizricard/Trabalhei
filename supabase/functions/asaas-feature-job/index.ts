// Gera a cobrança avulsa para destacar uma vaga por 7 dias.
// Body: { job_id: string, cpf_cnpj: string }
import {
  adminClient, asaas, getOrCreateCustomer, handle, HttpError, isoDate, json,
  requireUser, validateCpfCnpj,
} from "../_shared/common.ts";

const FEATURE_DAYS = 7;

Deno.serve(handle(async (req) => {
  const user = await requireUser(req);
  const body = await req.json().catch(() => ({}));
  const jobId = String(body.job_id ?? "");
  if (!jobId) throw new HttpError(400, "job_id é obrigatório.");
  const cpfCnpj = validateCpfCnpj(body.cpf_cnpj);

  const admin = adminClient();
  const { data: job } = await admin
    .from("jobs")
    .select("id, title, client_id, status")
    .eq("id", jobId)
    .maybeSingle();
  if (!job || job.client_id !== user.id) throw new HttpError(404, "Vaga não encontrada.");
  if (job.status !== "open") throw new HttpError(409, "Só é possível destacar vagas abertas.");

  const customerId = await getOrCreateCustomer(admin, user, cpfCnpj);
  const price = Number(Deno.env.get("FEATURE_PRICE") ?? "19.90");

  const due = new Date();
  due.setDate(due.getDate() + 1);

  // Cria o registro primeiro para termos o externalReference; completa com o id do Asaas depois.
  const featuringId = crypto.randomUUID();
  const payment = await asaas<{ id: string; invoiceUrl: string }>("/payments", {
    method: "POST",
    body: {
      customer: customerId,
      billingType: "UNDEFINED", // o cliente escolhe Pix/cartão/boleto na fatura
      value: price,
      dueDate: isoDate(due),
      description: `Destaque de vaga por ${FEATURE_DAYS} dias: ${job.title}`,
      externalReference: `feature:${featuringId}`,
    },
  });

  const { error } = await admin.from("job_featurings").insert({
    id: featuringId,
    job_id: job.id,
    user_id: user.id,
    asaas_payment_id: payment.id,
    days: FEATURE_DAYS,
    amount: price,
  });
  if (error) throw new HttpError(500, "Falha ao registrar o destaque.");

  return json({ invoice_url: payment.invoiceUrl });
}));
