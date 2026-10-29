import assert from "node:assert/strict";
import {
  customer,
  type Database,
  receive,
  reset,
  sqlFile,
} from "../webhook/fixtures.ts";
import {
  paid,
  refund,
  refundMigrations,
  remaining,
  revoked,
} from "./fixtures.ts";

export async function recoveryTests(t: Deno.TestContext, db: Database) {
  for (
    const table of [
      "jobs",
      "billing_payment_receipts",
      "job_featurings",
      "notifications",
    ]
  ) {
    await t.step(
      `estorno: falha em ${table} desfaz retirada, status e notificação`,
      async () => {
        await reset(db);
        const { userId, jobId } = await customer(db);
        const f = await paid(db, userId, jobId);
        const e = refund(f.paymentId);
        await db.unsafe(
          `create function public.test_refund_failure() returns trigger language plpgsql as $$
        begin raise exception 'TEST_REFUND_FAILURE'; end; $$;
        create trigger test_refund_failure before ${
            table === "notifications" ? "insert" : "update"
          } on public.${table}
        for each row execute function public.test_refund_failure()`,
        );
        try {
          assert.equal((await receive(db, e)).status, "failed");
        } finally {
          await db.unsafe(
            `drop trigger test_refund_failure on public.${table}; drop function public.test_refund_failure()`,
          );
        }
        await remaining(db, jobId, 7);
        const [r] =
          await db`select r.revoked_at,f.status,(select count(*)::int from public.notifications where user_id=${userId}) notices
        from public.billing_payment_receipts r join public.job_featurings f on f.asaas_payment_id=r.payment_id
        where r.payment_id=${f.paymentId}`;
        assert.equal(r.revoked_at, null);
        assert.equal(r.status, "paid");
        assert.equal(r.notices, 1);
        assert.equal((await receive(db, e)).status, "processed");
        await remaining(db, jobId, 0);
        await revoked(db, f.paymentId);
      },
    );
  }
  await t.step(
    "estorno: ausência de recibo pago não retira benefício sem atribuição segura",
    async () => {
      await reset(db);
      const { userId, jobId } = await customer(db);
      const f = await paid(db, userId, jobId);
      await db`delete from public.billing_payment_receipts where payment_id=${f.paymentId}`;
      assert.equal((await receive(db, refund(f.paymentId))).status, "failed");
      await remaining(db, jobId, 7);
    },
  );
  await t.step(
    "estorno: rollback recusa apagar histórico de revogação",
    async () => {
      await reset(db);
      const { userId, jobId } = await customer(db);
      const f = await paid(db, userId, jobId);
      await receive(db, refund(f.paymentId));
      for (const m of [...refundMigrations].reverse()) {
        await assert.rejects(
          () => sqlFile(db, `rollbacks/${m}_down.sql`),
          /FEATURE_REFUND_DATA_PRESENT/,
        );
      }
      await revoked(db, f.paymentId);
      await remaining(db, jobId, 0);
    },
  );
  await t.step(
    "estorno: anon/authenticated/service_role não chamam auxiliares privados",
    async () => {
      for (const role of ["anon", "authenticated", "service_role"]) {
        await assert.rejects(() =>
          db.begin(async (tx) => {
            await tx.unsafe(`set local role ${role}`);
            await tx`select billing_private.apply_feature_refund('test','{"id":"test"}'::jsonb)`;
          }), { code: "42501" });
      }
    },
  );
  await t.step(
    "estorno: RPC recusa pagamento sem id antes de persistir evento",
    async () => {
      await reset(db);
      const id = crypto.randomUUID();
      await assert.rejects(
        () => receive(db, { id, event: "PAYMENT_REFUNDED", payment: {} }),
        /INVALID_PAYMENT/,
      );
      const [e] =
        await db`select count(*)::int n from public.billing_events where id=${id}`;
      assert.equal(e.n, 0);
    },
  );
}
