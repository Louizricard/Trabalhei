import assert from "node:assert/strict";
import {
  customer,
  feature,
  install,
  paymentEvent,
  processingMigration,
  receiptsMigration,
  receive,
  reset,
  sqlFile,
  subscription,
  testDatabase,
  upgrade,
} from "./fixtures.ts";
import { paymentTests } from "./payments.ts";
import { recoveryTests } from "./recovery.ts";

Deno.test("webhook: transações, recuperação, concorrência e permissões em PostgreSQL", async (t) => {
  const db = testDatabase();
  try {
    await install(db);
    await t.step("migrations e rollbacks limpos são reaplicáveis", async () => {
      await sqlFile(db, `rollbacks/${processingMigration}_down.sql`);
      await sqlFile(db, `rollbacks/${receiptsMigration}_down.sql`);
      await upgrade(db);
    });
    await t.step(
      "histórico legado não reaplica benefícios durante upgrade",
      async () => {
        await sqlFile(db, `rollbacks/${processingMigration}_down.sql`);
        await sqlFile(db, `rollbacks/${receiptsMigration}_down.sql`);
        const { userId, jobId } = await customer(db);
        const { paymentId } = await feature(db, jobId, userId);
        const sub = await subscription(db, userId);
        const event = paymentEvent(paymentId);
        const proEvent = paymentEvent(crypto.randomUUID(), sub);
        await db`update public.jobs set featured_until=now()+interval '7 days' where id=${jobId}`;
        await db`update public.job_featurings set status='paid',paid_at=now() where asaas_payment_id=${paymentId}`;
        await db`update public.subscriptions set current_period_end=now()+interval '33 days' where user_id=${userId}`;
        for (const payload of [event, proEvent]) {
          await db`insert into public.billing_events (id,event,payload)
          values (${payload.id},${payload.event},${db.json(payload)})`;
        }
        await upgrade(db);
        assert.equal((await receive(db, event)).status, "legacy");
        await receive(
          db,
          paymentEvent(paymentId, undefined, "PAYMENT_CONFIRMED"),
        );
        await receive(
          db,
          paymentEvent(proEvent.payment.id, sub, "PAYMENT_CONFIRMED"),
        );
        const [counts] =
          await db`select (select count(*) from public.billing_payment_receipts)::int receipts,
        (select count(*) from public.notifications)::int notifications`;
        assert.equal(counts.receipts, 2);
        assert.equal(counts.notifications, 0);
      },
    );
    await paymentTests(t, db);
    await recoveryTests(t, db);
    await t.step(
      "evento ignorado é explícito; colisão de id não sobrescreve inbox",
      async () => {
        await reset(db);
        const payload = { id: crypto.randomUUID(), event: "PAYMENT_CREATED" };
        assert.equal((await receive(db, payload)).status, "ignored");
        await assert.rejects(
          receive(db, { ...payload, event: "SUBSCRIPTION_CREATED" }),
          { code: "22023" },
        );
        const [row] =
          await db`select event from public.billing_events where id=${payload.id}`;
        assert.equal(row.event, "PAYMENT_CREATED");
      },
    );
    await t.step(
      "anon e authenticated não executam RPCs nem leem recibos",
      async () => {
        for (const role of ["anon", "authenticated"]) {
          for (
            const query of [
              "select public.process_asaas_billing_event('test')",
              "select public.receive_asaas_billing_event('{}'::jsonb)",
              "select * from public.billing_payment_receipts",
              "select billing_private.apply_event(null::public.billing_events)",
            ]
          ) {
            await assert.rejects(
              db.begin(async (tx) => {
                await tx.unsafe(`set local role ${role}`);
                await tx.unsafe(query);
              }),
              { code: "42501" },
            );
          }
        }
      },
    );
    await t.step(
      "rollback operacional preserva inbox e rollback de schema protege dados novos",
      async () => {
        await assert.rejects(
          sqlFile(db, `rollbacks/${receiptsMigration}_down.sql`),
          /BILLING_DATA_PRESENT/,
        );
        const [before] =
          await db`select count(*)::int count from public.billing_events`;
        await sqlFile(db, `rollbacks/${processingMigration}_down.sql`);
        const [after] =
          await db`select count(*)::int count from public.billing_events`;
        assert.equal(after.count, before.count);
        await sqlFile(db, `migrations/${processingMigration}.sql`);
      },
    );
  } finally {
    await db.end();
  }
});
