import assert from "node:assert/strict";
import {
  customer,
  type Database,
  feature,
  paymentEvent,
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
import { timelineTests } from "./timeline.ts";
import { recoveryTests } from "./recovery.ts";

export async function refundTests(t: Deno.TestContext, db: Database) {
  await reset(db);
  await t.step(
    "estorno: upgrade preserva legado; rollback limpo é reaplicável",
    async () => {
      const { userId, jobId } = await customer(db);
      const f = await paid(db, userId, jobId);
      await db`update public.billing_payment_receipts set event_id=null where payment_id=${f.paymentId}`;
      const [before] =
        await db`select featured_until from public.jobs where id=${jobId}`;
      for (const m of refundMigrations) {
        await sqlFile(
          db,
          `migrations/${m}.sql`,
        );
      }
      const [after] =
        await db`select featured_until from public.jobs where id=${jobId}`;
      assert.deepEqual(after, before);
      for (const m of [...refundMigrations].reverse()) {
        await sqlFile(
          db,
          `rollbacks/${m}_down.sql`,
        );
      }
      for (const m of refundMigrations) {
        await sqlFile(
          db,
          `migrations/${m}.sql`,
        );
      }
      const [r] =
        await db`select feature_starts_at,feature_original_expires_at from public.billing_payment_receipts where payment_id=${f.paymentId}`;
      assert.ok(r.feature_starts_at);
      assert.ok(r.feature_original_expires_at);
    },
  );
  await t.step(
    "estorno: legado com períodos agregados ambíguos exige conciliação",
    async () => {
      await reset(db);
      const { userId, jobId } = await customer(db);
      await paid(db, userId, jobId);
      await paid(db, userId, jobId);
      for (const m of [...refundMigrations].reverse()) {
        await sqlFile(db, `rollbacks/${m}_down.sql`);
      }
      await db`update public.billing_payment_receipts set event_id=null`;
      await assert.rejects(
        () =>
          db.begin((tx) =>
            sqlFile(
              tx as unknown as Database,
              `migrations/${refundMigrations[0]}.sql`,
            )
          ),
        /RECONCILE_LEGACY_FEATURE_PERIODS/,
      );
      await remaining(db, jobId, 14);
      await reset(db);
      for (const m of refundMigrations) {
        await sqlFile(db, `migrations/${m}.sql`);
      }
    },
  );
  await t.step(
    "estorno total avulso retira destaque sem subscription nem externalReference",
    async () => {
      await reset(db);
      const { userId, jobId } = await customer(db);
      const f = await paid(db, userId, jobId);
      const e = {
        id: crypto.randomUUID(),
        event: "PAYMENT_REFUNDED",
        payment: { id: f.paymentId },
      };
      assert.equal((await receive(db, e)).status, "processed");
      await remaining(db, jobId, 0);
      await revoked(db, f.paymentId, 7 * 86400);
    },
  );
  await t.step(
    "estorno: reenvios e confirmações tardias não retiram nem concedem duas vezes",
    async () => {
      await reset(db);
      const { userId, jobId } = await customer(db);
      const f = await paid(db, userId, jobId);
      const e = refund(f.paymentId);
      await Promise.all(
        Array.from(
          { length: 8 },
          (_, i) => receive(db, i % 2 ? e : refund(f.paymentId)),
        ),
      );
      await receive(
        db,
        paymentEvent(f.paymentId, undefined, "PAYMENT_CONFIRMED"),
      );
      await remaining(db, jobId, 0);
      await revoked(db, f.paymentId);
      const [n] =
        await db`select count(*)::int n from public.notifications where user_id=${userId}`;
      assert.equal(n.n, 2);
    },
  );
  await t.step(
    "estorno antes do vínculo impede concessão posterior e é retomado pelo INSERT",
    async () => {
      await reset(db);
      const { userId, jobId } = await customer(db);
      const id = crypto.randomUUID();
      const e = refund(id);
      assert.equal((await receive(db, e)).status, "pending");
      await feature(db, jobId, userId, id);
      await receive(db, paymentEvent(id));
      const [j] =
        await db`select featured_until from public.jobs where id=${jobId}`;
      assert.equal(j.featured_until, null);
      await revoked(db, id, 0);
    },
  );
  await t.step(
    "estorno parcial, em processamento ou negado não cancela o benefício inteiro",
    async () => {
      await reset(db);
      const { userId, jobId } = await customer(db);
      const f = await paid(db, userId, jobId);
      for (
        const type of [
          "PAYMENT_PARTIALLY_REFUNDED",
          "PAYMENT_REFUND_IN_PROGRESS",
          "PAYMENT_REFUND_DENIED",
        ]
      ) {
        assert.equal(
          (await receive(db, refund(f.paymentId, type))).status,
          "ignored",
        );
      }
      await remaining(db, jobId, 7);
      const [r] =
        await db`select revoked_at from public.billing_payment_receipts where payment_id=${f.paymentId}`;
      assert.equal(r.revoked_at, null);
    },
  );
  await timelineTests(t, db);
  await recoveryTests(t, db);
}
