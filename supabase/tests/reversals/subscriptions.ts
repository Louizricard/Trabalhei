import assert from "node:assert/strict";
import {
  type Database,
  receive,
  reset,
  subscription,
} from "../webhook/fixtures.ts";
import { event, paidPro, pro, state } from "./fixtures.ts";
export async function subscriptionTests(t: Deno.TestContext, db: Database) {
  await t.step(
    "reversão Pro: estorno antigo preserva cobrança mais recente",
    async () => {
      await reset(db);
      const a = await paidPro(db);
      await shorten(db, a.payment);
      const b = crypto.randomUUID();
      await receive(db, event(b, a.sub));
      assert.equal(
        (await receive(db, event(a.payment, a.sub, "PAYMENT_REFUNDED"))).status,
        "processed",
      );
      await pro(db, a.userId, 33);
      await state(db, a.payment, "refunded");
      const [s] =
        await db`select status from public.subscriptions where asaas_subscription_id=${a.sub}`;
      assert.equal(s.status, "active");
    },
  );
  await t.step(
    "reversão Pro: estorno atual preserva os três dias de outra cobrança",
    async () => {
      await reset(db);
      const a = await paidPro(db);
      await shorten(db, a.payment);
      const b = crypto.randomUUID();
      await receive(db, event(b, a.sub));
      await receive(db, event(b, a.sub, "PAYMENT_REFUNDED"));
      await pro(db, a.userId, 3);
    },
  );
  await t.step(
    "reversão Pro: última cobrança é revogada uma vez e confirmação tardia não renova",
    async () => {
      await reset(db);
      const a = await paidPro(db);
      const e = event(a.payment, a.sub, "PAYMENT_REFUNDED");
      await receive(db, e);
      await receive(db, e);
      await receive(db, event(a.payment, a.sub, "PAYMENT_CONFIRMED"));
      await pro(db, a.userId, null);
    },
  );
  await t.step(
    "reversão Pro: assinatura cancelada antiga não altera a nova",
    async () => {
      await reset(db);
      const a = await paidPro(db);
      await db`update public.subscriptions set status='cancelled' where asaas_subscription_id=${a.sub}`;
      const next = await subscription(db, a.userId);
      await receive(db, event(crypto.randomUUID(), next));
      await receive(db, event(a.payment, a.sub, "PAYMENT_REFUNDED"));
      await pro(db, a.userId, 33);
      await receive(db, event(a.payment, a.sub));
      const [s] =
        await db`select status from public.subscriptions where asaas_subscription_id=${a.sub}`;
      assert.equal(s.status, "cancelled");
    },
  );
  await t.step(
    "reversão Pro: cupom tem prazo independente do pagamento estornado",
    async () => {
      await reset(db);
      const a = await paidPro(db);
      await db`select public.grant_pro(${a.userId},30,'Cupom de teste')`;
      await receive(db, event(a.payment, a.sub, "PAYMENT_REFUNDED"));
      await pro(db, a.userId, 63);
    },
  );
  await t.step(
    "reversão Pro: estorno sem subscription usa recibo e é recuperado após vínculo",
    async () => {
      await reset(db);
      const a = await paidPro(db);
      const refund = {
        id: crypto.randomUUID(),
        event: "PAYMENT_REFUNDED",
        payment: { id: a.payment },
      };
      await receive(db, refund);
      await pro(db, a.userId, null);
      const b = crypto.randomUUID(),
        early = { ...refund, id: crypto.randomUUID(), payment: { id: b } };
      assert.equal((await receive(db, early)).status, "pending");
      await receive(db, event(b, a.sub));
      await pro(db, a.userId, null);
      const [e] =
        await db`select processing_status from public.billing_events where id=${early.id}`;
      assert.equal(e.processing_status, "processed");
    },
  );
  await t.step(
    "reversão Pro: estorno anterior à confirmação deixa tombstone",
    async () => {
      await reset(db);
      const a = await paidPro(db);
      const p = crypto.randomUUID();
      await receive(db, event(p, a.sub, "PAYMENT_REFUNDED"));
      await receive(db, event(p, a.sub));
      await state(db, p, "refunded");
      await pro(db, a.userId, 33);
    },
  );
  await t.step(
    "reversão Pro: falha no perfil desfaz efeito e replay recupera",
    async () => {
      await reset(db);
      const a = await paidPro(db);
      await db`insert into public.webhook_test_failures values('profile')`;
      const e = event(a.payment, a.sub, "PAYMENT_REFUNDED");
      assert.equal((await receive(db, e)).status, "failed");
      await state(db, a.payment, "none");
      await db`delete from public.webhook_test_failures`;
      await receive(db, e);
      await pro(db, a.userId, null);
    },
  );
  await t.step(
    "reversão Pro: dois estornos concorrentes preservam a terceira compra",
    async () => {
      await reset(db);
      const a = await paidPro(db);
      const b = crypto.randomUUID(), c = crypto.randomUUID();
      await receive(db, event(b, a.sub));
      await receive(db, event(c, a.sub));
      await Promise.all([
        receive(db, event(a.payment, a.sub, "PAYMENT_REFUNDED")),
        receive(db, event(b, a.sub, "PAYMENT_REFUNDED")),
      ]);
      await pro(db, a.userId, 33);
      await state(db, a.payment, "refunded");
      await state(db, b, "refunded");
    },
  );
}
async function shorten(db: Database, payment: string) {
  await db`update public.billing_payment_receipts set expires_at=now()+interval '3 days',pro_original_expires_at=now()+interval '3 days' where payment_id=${payment}`;
}
