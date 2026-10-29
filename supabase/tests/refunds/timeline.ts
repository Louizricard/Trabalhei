import assert from "node:assert/strict";
import {
  customer,
  type Database,
  feature,
  paymentEvent,
  receive,
  reset,
} from "../webhook/fixtures.ts";
import { paid, refund, remaining, revoked } from "./fixtures.ts";

export async function timelineTests(t: Deno.TestContext, db: Database) {
  await t.step(
    "estorno preserva sete dias da outra compra e compacta o recibo posterior",
    async () => {
      await reset(db);
      const { userId, jobId } = await customer(db);
      const a = await paid(db, userId, jobId);
      const b = await paid(db, userId, jobId);
      await receive(db, refund(a.paymentId));
      await remaining(db, jobId, 7);
      const [r] =
        await db`select extract(epoch from(expires_at-feature_starts_at)) seconds,
      feature_original_expires_at>expires_at history from public.billing_payment_receipts where payment_id=${b.paymentId}`;
      assert.equal(Number(r.seconds), 7 * 86400);
      assert.equal(r.history, true);
      await receive(db, refund(b.paymentId));
      await remaining(db, jobId, 0);
    },
  );
  await t.step(
    "estorno retira só os quatro dias não consumidos e preserva os sete dias seguintes",
    async () => {
      await reset(db);
      const { userId, jobId } = await customer(db);
      const a = await paid(db, userId, jobId);
      await paid(db, userId, jobId);
      await db`update public.billing_payment_receipts set feature_starts_at=feature_starts_at-interval '3 days',
      expires_at=expires_at-interval '3 days' where product='job_feature'`;
      await db`update public.jobs set featured_until=featured_until-interval '3 days' where id=${jobId}`;
      await receive(db, refund(a.paymentId));
      await remaining(db, jobId, 7);
      await revoked(db, a.paymentId, 4 * 86400);
    },
  );
  await t.step(
    "estorno de período já vencido não consome uma compra mais recente",
    async () => {
      await reset(db);
      const { userId, jobId } = await customer(db);
      const a = await paid(db, userId, jobId);
      await db`update public.billing_payment_receipts set feature_starts_at=now()-interval '9 days',expires_at=now()-interval '2 days'
      where payment_id=${a.paymentId}`;
      await db`update public.jobs set featured_until=now()-interval '2 days' where id=${jobId}`;
      await paid(db, userId, jobId);
      await receive(db, refund(a.paymentId));
      await remaining(db, jobId, 7);
      await revoked(db, a.paymentId, 0);
    },
  );
  await t.step(
    "estorno preserva período concedido por cupom gratuito",
    async () => {
      await reset(db);
      const { userId, jobId } = await customer(db);
      const a = await paid(db, userId, jobId);
      await db`insert into public.coupons(code,product,percent_off) values('REFUNDFREE','job_feature',100)`;
      const [claim] =
        await db`select public.claim_billing_checkout(${userId},'job_feature',${jobId},'PIX','REFUNDFREE') c`;
      await db`select public.price_billing_checkout(${claim.c.checkout.id},${claim.c.token})`;
      await db`select public.release_billing_checkout(${claim.c.checkout.id},${claim.c.token})`;
      await receive(db, refund(a.paymentId));
      await remaining(db, jobId, 7);
      const [f] =
        await db`select status from public.job_featurings where job_id=${jobId} and amount=0`;
      assert.equal(f.status, "paid");
    },
  );
  await t.step(
    "dois estornos concorrentes preservam atomicidade da linha do tempo",
    async () => {
      await reset(db);
      const { userId, jobId } = await customer(db);
      const a = await paid(db, userId, jobId);
      const b = await paid(db, userId, jobId);
      await Promise.all([
        receive(db, refund(a.paymentId)),
        receive(db, refund(b.paymentId)),
      ]);
      await remaining(db, jobId, 0);
      await revoked(db, a.paymentId);
      await revoked(db, b.paymentId);
    },
  );
  await t.step(
    "estorno concorre com nova confirmação sem perder o novo destaque",
    async () => {
      await reset(db);
      const { userId, jobId } = await customer(db);
      const a = await paid(db, userId, jobId);
      const b = await feature(db, jobId, userId);
      await Promise.all([
        receive(db, refund(a.paymentId)),
        receive(db, paymentEvent(b.paymentId)),
      ]);
      await remaining(db, jobId, 7);
    },
  );
}
