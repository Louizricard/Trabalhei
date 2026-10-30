import assert from "node:assert/strict";
import {
  customer,
  type Database,
  feature,
  paymentEvent,
  receive,
  reset,
} from "../webhook/fixtures.ts";
import { remaining } from "../refunds/fixtures.ts";
import { event, paidPro, pro, state } from "./fixtures.ts";
export async function failureTests(t: Deno.TestContext, db: Database) {
  await db.unsafe(
    `create trigger reversal_test_receipt before update on public.billing_payment_receipts
    for each row execute function public.webhook_test_fail('receipt-update')`,
  );
  for (const product of ["pro", "feature"]) {
    for (const action of ["hold", "restore"]) {
      for (
        const stage of product === "pro"
          ? ["receipt-update", "profile", "subscription", "notification"]
          : ["receipt-update", "job", "featuring", "notification"]
      ) {
        await t.step(
          `reversão ${product}: falha em ${stage} durante ${action} é atômica`,
          async () => {
            await reset(db);
            let user: string,
              payment: string,
              sub: string | undefined,
              job: string | undefined;
            if (product === "pro") {
              const a = await paidPro(db);
              user = a.userId;
              sub = a.sub;
              payment = a.payment;
            } else {
              const a = await customer(db);
              user = a.userId;
              job = a.jobId;
              payment = (await feature(db, job, user)).paymentId;
              await receive(db, paymentEvent(payment));
            }
            if (action === "restore") {
              await receive(
                db,
                event(
                  payment,
                  sub,
                  "PAYMENT_CHARGEBACK_REQUESTED",
                  "2026-10-02",
                ),
              );
            }
            await db`insert into public.webhook_test_failures values(${stage})`;
            const e = event(
              payment,
              sub,
              action === "hold"
                ? "PAYMENT_CHARGEBACK_REQUESTED"
                : "PAYMENT_RECEIVED",
              "2026-10-05",
              action === "hold" ? "REQUESTED" : "REVERSED",
            );
            assert.equal((await receive(db, e)).status, "failed");
            await state(db, payment, action === "hold" ? "none" : "held");
            if (job) {
              await remaining(db, job, action === "hold" ? 7 : 0);
            } else await pro(db, user, action === "hold" ? 33 : null);
            await db`delete from public.webhook_test_failures`;
            assert.equal((await receive(db, e)).status, "processed");
            if (job) await remaining(db, job, action === "hold" ? 0 : 7);
            else await pro(db, user, action === "hold" ? null : 33);
          },
        );
      }
    }
  }
  await db.unsafe(
    "drop trigger reversal_test_receipt on public.billing_payment_receipts",
  );
}
