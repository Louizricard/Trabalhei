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
export async function edgeTests(t: Deno.TestContext, db: Database) {
  await t.step(
    "reversão: cobranças externas ao Trabalhei não bloqueiam a fila",
    async () => {
      const payment = {
        id: crypto.randomUUID(),
        externalReference: "other-product",
      };
      for (const kind of ["PAYMENT_RECEIVED", "PAYMENT_REFUNDED"]) {
        assert.equal(
          (await receive(db, { id: crypto.randomUUID(), event: kind, payment }))
            .status,
          "ignored",
        );
      }
    },
  );
  await t.step(
    "chargeback destaque: outra compra preservada e restauração limita saldo não vencido",
    async () => {
      await reset(db);
      const a = await customer(db), f = await feature(db, a.jobId, a.userId);
      await receive(db, paymentEvent(f.paymentId));
      const b = await feature(db, a.jobId, a.userId);
      await receive(db, paymentEvent(b.paymentId));
      await receive(
        db,
        event(
          f.paymentId,
          undefined,
          "PAYMENT_CHARGEBACK_REQUESTED",
          "2026-10-02",
        ),
      );
      await remaining(db, a.jobId, 7);
      await db`update public.billing_payment_receipts set expires_at=now()+interval '4 days' where payment_id=${f.paymentId}`;
      await receive(
        db,
        event(
          f.paymentId,
          undefined,
          "PAYMENT_RECEIVED",
          "2026-10-05",
          "REVERSED",
        ),
      );
      await remaining(db, a.jobId, 11);
      await receive(
        db,
        event(
          f.paymentId,
          undefined,
          "PAYMENT_CONFIRMED",
          "2026-10-06",
          "REVERSED",
        ),
      );
      await remaining(db, a.jobId, 11);
    },
  );
  await t.step(
    "chargeback Pro: período já vencido não ganha novos 33 dias na restauração",
    async () => {
      await reset(db);
      const a = await paidPro(db);
      await receive(
        db,
        event(a.payment, a.sub, "PAYMENT_CHARGEBACK_REQUESTED", "2026-10-02"),
      );
      await db`update public.billing_payment_receipts set pro_original_expires_at=now()-interval '1 day' where payment_id=${a.payment}`;
      await receive(
        db,
        event(a.payment, a.sub, "PAYMENT_RECEIVED", "2026-10-05", "REVERSED"),
      );
      await pro(db, a.userId, null);
    },
  );
  await t.step(
    "chargeback: confirmação com estado disputado não libera benefício",
    async () => {
      await reset(db);
      const a = await paidPro(db), p = crypto.randomUUID();
      await receive(
        db,
        event(p, a.sub, "PAYMENT_CONFIRMED", "2026-10-02", "REQUESTED"),
      );
      await state(db, p, "held");
      await receive(db, event(a.payment, a.sub, "PAYMENT_REFUNDED"));
      await pro(db, a.userId, null);
      await receive(
        db,
        event(p, a.sub, "PAYMENT_RECEIVED", "2026-10-05", "REVERSED"),
      );
      await pro(db, a.userId, 33);
    },
  );
  await t.step(
    "chargeback: vitória antes do pedido atrasado não perde benefício",
    async () => {
      await reset(db);
      const a = await paidPro(db);
      await receive(
        db,
        event(a.payment, a.sub, "PAYMENT_RECEIVED", "2026-10-05", "REVERSED"),
      );
      await receive(
        db,
        event(
          a.payment,
          a.sub,
          "PAYMENT_CHARGEBACK_REQUESTED",
          "2026-10-02",
          "REQUESTED",
        ),
      );
      await pro(db, a.userId, 33);
      await state(db, a.payment, "restored");
    },
  );
  await t.step(
    "estorno Pro: parcial ou pendente não remove o benefício inteiro",
    async () => {
      await reset(db);
      const a = await paidPro(db);
      for (
        const refunds of [[{ status: "DONE", value: 5 }], [{
          status: "PENDING",
          value: 20,
        }]]
      ) {
        const e = event(a.payment, a.sub, "PAYMENT_REFUNDED");
        Object.assign(e.payment, { value: 20, refunds });
        assert.equal((await receive(db, e)).status, "ignored");
        await pro(db, a.userId, 33);
      }
      const e = event(a.payment, a.sub, "PAYMENT_REFUNDED");
      Object.assign(e.payment, {
        value: 20,
        refunds: [{ status: "DONE", value: 5 }, { status: "DONE", value: 15 }],
      });
      await receive(db, e);
      await pro(db, a.userId, null);
    },
  );
  await t.step(
    "reversão: recibo não pode ser movido para assinatura de outra pessoa",
    async () => {
      await reset(db);
      const a = await paidPro(db), b = await paidPro(db);
      assert.equal(
        (await receive(db, event(a.payment, b.sub, "PAYMENT_REFUNDED"))).status,
        "failed",
      );
      await pro(db, a.userId, 33);
      await pro(db, b.userId, 33);
    },
  );
  await t.step(
    "reversão: helpers e concessões são privados e RPC valida payment.id",
    async () => {
      const [r] =
        await db`select count(*)::int n from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='billing_private' and (has_function_privilege('anon',p.oid,'EXECUTE') or has_function_privilege('authenticated',p.oid,'EXECUTE'))`;
      assert.equal(r.n, 0);
      for (const role of ["anon", "authenticated"]) {
        const [r] =
          await db`select has_table_privilege(${role},'public.billing_pro_grants','SELECT') readable`;
        assert.equal(r.readable, false);
      }
      for (
        const kind of [
          "PAYMENT_CHARGEBACK_REQUESTED",
          "PAYMENT_CHARGEBACK_DISPUTE",
          "PAYMENT_AWAITING_CHARGEBACK_REVERSAL",
        ]
      ) {
        await assert.rejects(
          () => receive(db, { id: crypto.randomUUID(), event: kind }),
          /INVALID_PAYMENT/,
        );
      }
    },
  );
}
