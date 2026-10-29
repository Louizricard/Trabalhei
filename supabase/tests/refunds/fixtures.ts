import assert from "node:assert/strict";
import {
  type Database,
  feature,
  paymentEvent,
  receive,
} from "../webhook/fixtures.ts";
export const refundMigrations = [
  "20261029180258_feature_refund_receipts",
  "20261029180302_feature_refund_processing",
  "20261029180307_feature_refund_routing",
];

export function refund(paymentId: string, event = "PAYMENT_REFUNDED") {
  return {
    id: crypto.randomUUID(),
    event,
    payment: { id: paymentId, externalReference: `feature:${paymentId}` },
  };
}
export async function paid(db: Database, userId: string, jobId: string) {
  const f = await feature(db, jobId, userId);
  await receive(db, paymentEvent(f.paymentId));
  return f;
}
export async function remaining(db: Database, jobId: string, days: number) {
  const [row] =
    await db`select extract(epoch from(featured_until-now()))/86400 days from public.jobs where id=${jobId}`;
  assert.ok(
    Math.abs(Number(row.days) - days) < 0.005,
    `Expected ${days} days, received ${row.days}`,
  );
}
export async function revoked(db: Database, payment: string, seconds?: number) {
  const [row] =
    await db`select r.revoked_at,r.revoked_seconds,f.status from public.billing_payment_receipts r
    join public.job_featurings f on f.asaas_payment_id=r.payment_id where r.payment_id=${payment}`;
  assert.ok(row.revoked_at);
  assert.equal(row.status, "cancelled");
  if (seconds != null) {
    assert.ok(Math.abs(Number(row.revoked_seconds) - seconds) < 5);
  }
}
