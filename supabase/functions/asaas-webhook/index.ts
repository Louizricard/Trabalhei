// Webhook do Asaas. Configure no painel do Asaas:
//   URL:   https://<projeto>.functions.supabase.co/asaas-webhook
//   Token: o mesmo valor do secret ASAAS_WEBHOOK_TOKEN
// Eventos: PAYMENT_* e SUBSCRIPTION_*. Esta função é idempotente (billing_events).
import { adminClient, corsHeaders, env, json } from "../_shared/common.ts";

const PAID_EVENTS = new Set(["PAYMENT_CONFIRMED", "PAYMENT_RECEIVED"]);
const REVOKE_EVENTS = new Set(["PAYMENT_REFUNDED", "PAYMENT_CHARGEBACK_REQUESTED"]);
// Período pago + folga para o próximo ciclo ser confirmado.
const PRO_PERIOD_DAYS = 33;

function timingSafeEqual(a: string, b: string): boolean {
  const ea = new TextEncoder().encode(a);
  const eb = new TextEncoder().encode(b);
  if (ea.length !== eb.length) return false;
  let diff = 0;
  for (let i = 0; i < ea.length; i++) diff |= ea[i] ^ eb[i];
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Método não permitido." }, 405);

  const token = req.headers.get("asaas-access-token") ?? "";
  if (!timingSafeEqual(token, env("ASAAS_WEBHOOK_TOKEN"))) {
    return json({ error: "Token inválido." }, 401);
  }

  // deno-lint-ignore no-explicit-any
  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: "JSON inválido." }, 400);
  }

  const eventId: string | undefined = body?.id;
  const event: string | undefined = body?.event;
  if (!eventId || !event) return json({ error: "Evento inválido." }, 400);

  const admin = adminClient();

  // Idempotência: a PK de billing_events rejeita reprocessamento.
  const { error: dupError } = await admin
    .from("billing_events")
    .insert({ id: eventId, event, payload: body });
  if (dupError) {
    if (dupError.code === "23505") return json({ ok: true, duplicate: true });
    console.error("[webhook] billing_events", dupError);
    return json({ error: "Falha ao registrar evento." }, 500);
  }

  try {
    const payment = body.payment;
    const externalRef: string = payment?.externalReference ?? "";

    if (PAID_EVENTS.has(event) && payment) {
      if (externalRef.startsWith("feature:")) {
        await handleFeaturePaid(admin, payment.id);
      } else if (payment.subscription) {
        await handleSubscriptionPaid(admin, payment.subscription);
      }
    } else if (REVOKE_EVENTS.has(event) && payment) {
      if (payment.subscription) await revokeSubscription(admin, payment.subscription, "cancelled");
    } else if (event === "PAYMENT_OVERDUE" && payment?.subscription) {
      await admin.from("subscriptions").update({ status: "overdue" })
        .eq("asaas_subscription_id", payment.subscription);
    } else if (
      (event === "SUBSCRIPTION_INACTIVATED" || event === "SUBSCRIPTION_DELETED") &&
      body.subscription?.id
    ) {
      // O plano continua até plan_expires_at (período já pago).
      await admin.from("subscriptions").update({ status: "cancelled" })
        .eq("asaas_subscription_id", body.subscription.id);
    }
  } catch (e) {
    // Desfaz o registro para o Asaas reenviar o evento.
    await admin.from("billing_events").delete().eq("id", eventId);
    console.error("[webhook] processamento falhou", e);
    return json({ error: "Falha ao processar." }, 500);
  }

  return json({ ok: true });
});

// deno-lint-ignore no-explicit-any
async function handleSubscriptionPaid(admin: any, asaasSubscriptionId: string) {
  const { data: sub, error } = await admin
    .from("subscriptions")
    .update({ status: "active" })
    .eq("asaas_subscription_id", asaasSubscriptionId)
    .select("user_id")
    .maybeSingle();
  if (error) throw error;
  if (!sub) return;
  const expires = new Date(Date.now() + PRO_PERIOD_DAYS * 86400_000).toISOString();
  await admin.from("subscriptions").update({ current_period_end: expires })
    .eq("asaas_subscription_id", asaasSubscriptionId);
  const { error: pErr } = await admin.from("profiles")
    .update({ plan: "pro", plan_expires_at: expires }).eq("id", sub.user_id);
  if (pErr) throw pErr;
  await admin.rpc("notify", {
    p_user: sub.user_id, p_type: "system", p_title: "Plano Pro ativo 🎉",
    p_body: "Propostas ilimitadas liberadas. Obrigado por apoiar o Trabalhei!",
    p_data: { route: "/plans" },
  });
}

// deno-lint-ignore no-explicit-any
async function revokeSubscription(admin: any, asaasSubscriptionId: string, status: string) {
  const { data: sub } = await admin.from("subscriptions")
    .update({ status }).eq("asaas_subscription_id", asaasSubscriptionId)
    .select("user_id").maybeSingle();
  if (sub) {
    await admin.from("profiles")
      .update({ plan: "free", plan_expires_at: null }).eq("id", sub.user_id);
  }
}

// deno-lint-ignore no-explicit-any
async function handleFeaturePaid(admin: any, asaasPaymentId: string) {
  const { data: f } = await admin.from("job_featurings")
    .select("id, job_id, user_id, days, status").eq("asaas_payment_id", asaasPaymentId).maybeSingle();
  if (!f || f.status === "paid") return;
  const { data: job } = await admin.from("jobs").select("featured_until").eq("id", f.job_id).single();
  const base = job?.featured_until && new Date(job.featured_until) > new Date()
    ? new Date(job.featured_until)
    : new Date();
  const until = new Date(base.getTime() + f.days * 86400_000).toISOString();
  const { error } = await admin.from("jobs").update({ featured_until: until }).eq("id", f.job_id);
  if (error) throw error;
  await admin.from("job_featurings")
    .update({ status: "paid", paid_at: new Date().toISOString() }).eq("id", f.id);
  await admin.rpc("notify", {
    p_user: f.user_id, p_type: "system", p_title: "Vaga em destaque ⭐",
    p_body: "Pagamento confirmado. Sua vaga já aparece em destaque no mural.",
    p_data: { job_id: f.job_id, route: `/jobs/${f.job_id}` },
  });
}
