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
export async function chargebackTests(t: Deno.TestContext, db: Database) {
  for (const product of ["pro", "feature"]) {
    await t.step(
      `chargeback ${product}: suspensão, disputa, repasse e replay são idempotentes`,
      async () => {
        await reset(db);
        let user: string,
          job: string | undefined,
          sub: string | undefined,
          payment: string;
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
        const send = (kind: string, clock: string, cb?: string) =>
          receive(db, event(payment, sub, kind, clock, cb));
        await send(
          "PAYMENT_CHARGEBACK_REQUESTED",
          "2026-10-02T10:00:00Z",
          "REQUESTED",
        );
        await state(db, payment, "held");
        if (job) await remaining(db, job, 0);
        else await pro(db, user, null);
        await send(
          "PAYMENT_CHARGEBACK_DISPUTE",
          "2026-10-03T10:00:00Z",
          "IN_DISPUTE",
        );
        await send("PAYMENT_RECEIVED", "2026-10-01T11:00:00Z");
        await state(db, payment, "held");
        await send(
          "PAYMENT_AWAITING_CHARGEBACK_REVERSAL",
          "2026-10-04T10:00:00Z",
        );
        await state(db, payment, "awaiting");
        if (job) await remaining(db, job, 0);
        else await pro(db, user, null);
        await send("PAYMENT_RECEIVED", "2026-10-05T10:00:00Z", "REVERSED");
        await state(db, payment, "restored");
        if (job) await remaining(db, job, 7);
        else await pro(db, user, 33);
        await send("PAYMENT_CONFIRMED", "2026-10-05T10:00:01Z", "REVERSED");
        await send(
          "PAYMENT_CHARGEBACK_REQUESTED",
          "2026-10-02T10:00:00Z",
          "REQUESTED",
        );
        if (job) await remaining(db, job, 7);
        else await pro(db, user, 33);
      },
    );
  }
  await t.step(
    "chargeback: estorno definitivo não é restaurado após vitória tardia",
    async () => {
      await reset(db);
      const a = await paidPro(db);
      await receive(
        db,
        event(
          a.payment,
          a.sub,
          "PAYMENT_CHARGEBACK_DISPUTE",
          "2026-10-02",
          "IN_DISPUTE",
        ),
      );
      await receive(
        db,
        event(a.payment, a.sub, "PAYMENT_REFUNDED", "2026-10-03"),
      );
      await receive(
        db,
        event(a.payment, a.sub, "PAYMENT_RECEIVED", "2026-10-04", "REVERSED"),
      );
      await state(db, a.payment, "refunded");
      await pro(db, a.userId, null);
    },
  );
  await t.step(
    "chargeback: confirmação após awaiting exige evento posterior",
    async () => {
      await reset(db);
      const a = await paidPro(db);
      await receive(
        db,
        event(
          a.payment,
          a.sub,
          "PAYMENT_AWAITING_CHARGEBACK_REVERSAL",
          "2026-10-04",
        ),
      );
      await receive(
        db,
        event(a.payment, a.sub, "PAYMENT_RECEIVED", "2026-10-01"),
      );
      await state(db, a.payment, "awaiting");
      await pro(db, a.userId, null);
      await receive(
        db,
        event(a.payment, a.sub, "PAYMENT_RECEIVED", "2026-10-05"),
      );
      await pro(db, a.userId, 33);
    },
  );
  await t.step(
    "chargeback: suspensão da compra antiga preserva outra cobrança válida",
    async () => {
      await reset(db);
      const a = await paidPro(db);
      await receive(db, event(crypto.randomUUID(), a.sub));
      await receive(
        db,
        event(a.payment, a.sub, "PAYMENT_CHARGEBACK_REQUESTED", "2026-10-02"),
      );
      await pro(db, a.userId, 33);
    },
  );
  await t.step(
    "chargeback: evento anterior ao vínculo é recuperado sem conceder até repasse",
    async () => {
      await reset(db);
      const a = await customer(db);
      const payment = crypto.randomUUID();
      assert.equal(
        (await receive(
          db,
          event(payment, undefined, "PAYMENT_CHARGEBACK_DISPUTE", "2026-10-02"),
        )).status,
        "pending",
      );
      await feature(db, a.jobId, a.userId, payment);
      await state(db, payment, "held");
      await receive(db, event(payment));
      await remaining(db, a.jobId, 0);
      await receive(
        db,
        event(payment, undefined, "PAYMENT_RECEIVED", "2026-10-05", "REVERSED"),
      );
      await remaining(db, a.jobId, 7);
    },
  );
  await t.step(
    "chargeback: estado desconhecido e restauração ambígua ficam pendentes",
    async () => {
      await reset(db);
      const a = await paidPro(db);
      assert.equal(
        (await receive(
          db,
          event(a.payment, a.sub, "PAYMENT_UPDATED", "2026-10-02", "UNKNOWN"),
        )).status,
        "pending",
      );
      await receive(
        db,
        event(
          a.payment,
          a.sub,
          "PAYMENT_AWAITING_CHARGEBACK_REVERSAL",
          "2026-10-04",
        ),
      );
      const ambiguous = event(a.payment, a.sub);
      delete (ambiguous as { dateCreated?: string }).dateCreated;
      assert.equal((await receive(db, ambiguous)).status, "pending");
      await pro(db, a.userId, null);
    },
  );
}
