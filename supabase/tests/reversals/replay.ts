import assert from "node:assert/strict";
import {
  customer,
  type Database,
  receive,
  reset,
  subscription,
} from "../webhook/fixtures.ts";
import { event, pro, state } from "./fixtures.ts";
export async function replayTests(t: Deno.TestContext, db: Database) {
  await t.step(
    "replay: falha no estorno vinculado desfaz confirmação e benefício",
    async () => {
      await reset(db);
      const { userId } = await customer(db),
        sub = await subscription(db, userId),
        payment = crypto.randomUUID();
      const refund = {
        id: crypto.randomUUID(),
        event: "PAYMENT_REFUNDED",
        payment: { id: payment },
      };
      assert.equal((await receive(db, refund)).status, "pending");
      await db.unsafe(
        `create trigger replay_test_receipt before update on public.billing_payment_receipts
      for each row execute function public.webhook_test_fail('replay-receipt')`,
      );
      await db`insert into public.webhook_test_failures values('replay-receipt')`;
      const paid = event(payment, sub);
      try {
        assert.equal((await receive(db, paid)).status, "failed");
        await pro(db, userId, null);
        const [r] =
          await db`select (select count(*)::int from public.billing_payment_receipts) receipts,
        (select count(*)::int from public.notifications) notifications`;
        assert.deepEqual(r, { receipts: 0, notifications: 0 });
        await db`delete from public.webhook_test_failures`;
        assert.equal((await receive(db, paid)).status, "processed");
        await pro(db, userId, null);
        await state(db, payment, "refunded");
        const [e] =
          await db`select processing_status from public.billing_events where id=${refund.id}`;
        assert.equal(e.processing_status, "processed");
      } finally {
        await db`delete from public.webhook_test_failures`;
        await db.unsafe(
          "drop trigger replay_test_receipt on public.billing_payment_receipts",
        );
      }
    },
  );
  await t.step(
    "replay: chargeback desconhecido pendente bloqueia concessão pela confirmação",
    async () => {
      await reset(db);
      const { userId } = await customer(db),
        sub = await subscription(db, userId),
        payment = crypto.randomUUID();
      const unknown = {
        id: crypto.randomUUID(),
        event: "PAYMENT_CHARGEBACK_REQUESTED",
        payment: { id: payment, chargeback: { status: "UNKNOWN" } },
      };
      assert.equal((await receive(db, unknown)).status, "pending");
      assert.equal((await receive(db, event(payment, sub))).status, "failed");
      await pro(db, userId, null);
    },
  );
}
