import assert from "node:assert/strict";
import {
  assertFeature,
  customer,
  type Database,
  feature,
  paymentEvent,
  receive,
  reset,
  subscription,
} from "./fixtures.ts";

export async function paymentTests(t: Deno.TestContext, db: Database) {
  await t.step(
    "reenvios e CONFIRMED/RECEIVED concorrentes aplicam destaque uma vez",
    async () => {
      await reset(db);
      const { userId, jobId } = await customer(db);
      const { paymentId } = await feature(db, jobId, userId);
      const event = paymentEvent(paymentId);
      const confirmed = paymentEvent(paymentId, undefined, "PAYMENT_CONFIRMED");
      await Promise.all(
        Array.from(
          { length: 8 },
          (_, i) => receive(db, i % 2 ? event : confirmed),
        ),
      );
      await assertFeature(db, jobId, 7);
      assert.equal((await receive(db, event)).duplicate, true);
      await assertFeature(db, jobId, 7);
    },
  );

  await t.step(
    "dois pagamentos da mesma vaga somam os dias sem perder atualização",
    async () => {
      await reset(db);
      const { userId, jobId } = await customer(db);
      const a = await feature(db, jobId, userId);
      const b = await feature(db, jobId, userId);
      await Promise.all([
        receive(db, paymentEvent(a.paymentId)),
        receive(db, paymentEvent(b.paymentId)),
      ]);
      await assertFeature(db, jobId, 14, 2);
    },
  );

  await t.step(
    "assinatura: um pagamento não renova nem notifica duas vezes",
    async () => {
      await reset(db);
      const { userId } = await customer(db);
      const sub = await subscription(db, userId);
      const payment = crypto.randomUUID();
      await Promise.all([
        receive(db, paymentEvent(payment, sub)),
        receive(db, paymentEvent(payment, sub, "PAYMENT_CONFIRMED")),
      ]);
      const [row] =
        await db`select p.plan, p.plan_expires_at=s.current_period_end consistent,
      (select count(*) from public.billing_payment_receipts)::int receipts,
      (select count(*) from public.notifications)::int notifications
      from public.profiles p join public.subscriptions s on s.user_id=p.id where p.id=${userId}`;
      assert.equal(row.plan, "pro");
      assert.equal(row.consistent, true);
      assert.equal(row.receipts, 1);
      assert.equal(row.notifications, 1);
    },
  );

  await t.step(
    "evento antes do vínculo continua pendente e o INSERT retoma sozinho",
    async () => {
      await reset(db);
      const { userId, jobId } = await customer(db);
      const payment = crypto.randomUUID();
      const event = paymentEvent(payment);
      assert.equal((await receive(db, event)).status, "pending");
      const [pending] =
        await db`select processed_at from public.billing_events where id=${event.id}`;
      assert.equal(pending.processed_at, null);
      await feature(db, jobId, userId, payment);
      await assertFeature(db, jobId, 7);
      assert.equal((await receive(db, event)).status, "processed");
    },
  );

  await t.step(
    "assinatura inserida depois do webhook também recupera o evento",
    async () => {
      await reset(db);
      const { userId } = await customer(db);
      const sub = crypto.randomUUID();
      const event = paymentEvent(crypto.randomUUID(), sub);
      assert.equal((await receive(db, event)).status, "pending");
      await subscription(db, userId, sub);
      const [row] =
        await db`select plan from public.profiles where id=${userId}`;
      assert.equal(row.plan, "pro");
      assert.equal((await receive(db, event)).status, "processed");
    },
  );

  await t.step(
    "cancelamento mantém período pago e atraso/estorno conservam regra existente",
    async () => {
      await reset(db);
      const { userId } = await customer(db);
      const sub = await subscription(db, userId);
      await receive(db, paymentEvent(crypto.randomUUID(), sub));
      await receive(db, {
        id: crypto.randomUUID(),
        event: "SUBSCRIPTION_DELETED",
        subscription: { id: sub },
      });
      const [profile] =
        await db`select plan from public.profiles where id=${userId}`;
      assert.equal(profile.plan, "pro");
      await receive(
        db,
        paymentEvent(crypto.randomUUID(), sub, "PAYMENT_OVERDUE"),
      );
      const [overdue] =
        await db`select status from public.subscriptions where user_id=${userId}`;
      assert.equal(overdue.status, "overdue");
      await receive(
        db,
        paymentEvent(crypto.randomUUID(), sub, "PAYMENT_REFUNDED"),
      );
      const [revoked] =
        await db`select plan from public.profiles where id=${userId}`;
      assert.equal(revoked.plan, "free");
    },
  );
}
