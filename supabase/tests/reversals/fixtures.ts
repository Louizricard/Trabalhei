import assert from "node:assert/strict";
import {
  customer,
  type Database,
  paymentEvent,
  receive,
  subscription,
} from "../webhook/fixtures.ts";
export const migrations = [
  "20261030023123_billing_reversal_ledger",
  "20261030023125_billing_subscription_credits",
  "20261030023127_billing_feature_reversals",
  "20261030023129_billing_reversal_state",
  "20261030023132_billing_reversal_routing",
];
export function event(
  payment: string,
  sub?: string,
  kind = "PAYMENT_RECEIVED",
  clock = "2026-10-01T10:00:00Z",
  cb?: string,
) {
  return {
    ...paymentEvent(payment, sub, kind),
    dateCreated: clock,
    payment: {
      id: payment,
      ...(sub
        ? { subscription: sub }
        : { externalReference: "feature:" + payment }),
      ...(cb ? { chargeback: { status: cb } } : {}),
    },
  };
}
export async function paidPro(db: Database) {
  const { userId } = await customer(db);
  const sub = await subscription(db, userId);
  const payment = crypto.randomUUID();
  assert.equal((await receive(db, event(payment, sub))).status, "processed");
  return { userId, sub, payment };
}
export async function pro(db: Database, user: string, days: number | null) {
  const [p] =
    await db`select plan,extract(epoch from(plan_expires_at-now()))/86400 days from public.profiles where id=${user}`;
  assert.equal(p.plan, days === null ? "free" : "pro");
  if (days !== null) {
    assert.ok(
      Math.abs(Number(p.days) - days) < 0.005,
      `Expected Pro ${days} days, got ${p.days}`,
    );
  }
}
export async function state(db: Database, payment: string, expected: string) {
  const [r] =
    await db`select reversal_state from public.billing_payment_receipts where payment_id=${payment}`;
  assert.equal(r.reversal_state, expected);
}
