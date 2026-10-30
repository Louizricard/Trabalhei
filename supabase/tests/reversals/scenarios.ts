import assert from "node:assert/strict";
import {
  customer,
  type Database,
  paymentEvent,
  receive,
  reset,
  sqlFile,
  subscription,
} from "../webhook/fixtures.ts";
import { event, migrations, paidPro } from "./fixtures.ts";
import { subscriptionTests } from "./subscriptions.ts";
import { chargebackTests } from "./chargebacks.ts";
import { edgeTests } from "./edges.ts";
import { failureTests } from "./failures.ts";
import { replayTests } from "./replay.ts";
export async function reversalTests(t: Deno.TestContext, db: Database) {
  await reset(db);
  await t.step(
    "reversões: seed Pro preserva prazos e rollbacks limpos são reaplicáveis",
    async () => {
      const a = await customer(db);
      const sub = await subscription(db, a.userId);
      await receive(db, paymentEvent(crypto.randomUUID(), sub));
      await db`update public.billing_payment_receipts set applied_at=now()-interval '30 days' where product='pro_monthly'`;
      const [before] =
        await db`select plan,plan_expires_at from public.profiles where id=${a.userId}`;
      for (const m of migrations) await sqlFile(db, `migrations/${m}.sql`);
      const [legacy] =
        await db`select extract(epoch from(pro_original_expires_at-now()))/86400 days from public.billing_payment_receipts where product='pro_monthly'`;
      assert.ok(Math.abs(Number(legacy.days) - 3) < 0.005);
      const [after] =
        await db`select plan,plan_expires_at from public.profiles where id=${a.userId}`;
      assert.deepEqual(after, before);
      for (const m of [...migrations].reverse()) {
        await sqlFile(db, `rollbacks/${m}_down.sql`);
      }
      for (const m of migrations) await sqlFile(db, `migrations/${m}.sql`);
    },
  );
  await subscriptionTests(t, db);
  await chargebackTests(t, db);
  await edgeTests(t, db);
  await failureTests(t, db);
  await replayTests(t, db);
  await t.step(
    "reversões: dados financeiros novos bloqueiam rollback destrutivo",
    async () => {
      const a = await paidPro(db);
      await receive(db, event(a.payment, a.sub, "PAYMENT_REFUNDED"));
      for (const m of [...migrations].reverse()) {
        await assert.rejects(
          () => sqlFile(db, `rollbacks/${m}_down.sql`),
          /BILLING_REVERSAL_DATA_PRESENT/,
        );
      }
    },
  );
}
