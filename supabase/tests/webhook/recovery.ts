import assert from "node:assert/strict";
import {
  assertFeature,
  customer,
  type Database,
  feature,
  paymentEvent,
  receive,
  reset,
  subscription,
} from "./fixtures.ts";

export async function recoveryTests(t: Deno.TestContext, db: Database) {
  await db`create table public.webhook_test_failures (stage text primary key)`;
  await db.unsafe(
    `create function public.webhook_test_fail() returns trigger language plpgsql as $$
    begin
      if exists (select 1 from public.webhook_test_failures where stage=tg_argv[0]) then
        raise exception 'INJECTED_FAILURE' using errcode='22000';
      end if;
      return new;
    end $$`,
  );
  for (
    const [table, stage] of [
      ["jobs", "job"],
      ["job_featurings", "featuring"],
      [
        "profiles",
        "profile",
      ],
      ["subscriptions", "subscription"],
      ["billing_payment_receipts", "receipt"],
      ["notifications", "notification"],
    ]
  ) {
    await db.unsafe(
      `create trigger webhook_test_${stage} before ${
        ["notifications", "billing_payment_receipts"].includes(table)
          ? "insert"
          : "update"
      }
      on public.${table} for each row execute function public.webhook_test_fail('${stage}')`,
    );
  }

  for (const stage of ["receipt", "job", "featuring", "notification"]) {
    await t.step(
      `falha em ${stage} desfaz o destaque inteiro e reenvio recupera`,
      async () => {
        await reset(db);
        const { userId, jobId } = await customer(db);
        const { paymentId } = await feature(db, jobId, userId);
        const event = paymentEvent(paymentId);
        await db`insert into public.webhook_test_failures values (${stage})`;
        assert.equal((await receive(db, event)).status, "failed");
        const [row] = await db`select j.featured_until, f.status,
        (select count(*) from public.billing_payment_receipts)::int receipts
        from public.jobs j join public.job_featurings f on f.job_id=j.id where j.id=${jobId}`;
        assert.equal(row.featured_until, null);
        assert.equal(row.status, "pending");
        assert.equal(row.receipts, 0);
        await db`delete from public.webhook_test_failures`;
        assert.equal((await receive(db, event)).status, "processed");
        await assertFeature(db, jobId, 7);
        const [inbox] =
          await db`select attempts, last_error_code from public.billing_events where id=${event.id}`;
        assert.equal(inbox.attempts, 2);
        assert.equal(inbox.last_error_code, null);
      },
    );
  }

  for (const stage of ["subscription", "profile", "notification"]) {
    await t.step(
      `falha em ${stage} desfaz assinatura/recibo e reprocessamento recupera`,
      async () => {
        await reset(db);
        const { userId } = await customer(db);
        const sub = await subscription(db, userId);
        const event = paymentEvent(crypto.randomUUID(), sub);
        await db`insert into public.webhook_test_failures values (${stage})`;
        assert.equal((await receive(db, event)).status, "failed");
        const [row] =
          await db`select status,current_period_end from public.subscriptions where user_id=${userId}`;
        assert.equal(row.status, "pending");
        assert.equal(row.current_period_end, null);
        await db`delete from public.webhook_test_failures`;
        const [result] =
          await db`select public.process_asaas_billing_event(${event.id}) result`;
        assert.equal(result.result.status, "processed");
      },
    );
  }

  await t.step(
    "transação interrompida não deixa efeito parcial nem bloqueia nova entrega",
    async () => {
      await reset(db);
      const { userId, jobId } = await customer(db);
      const { paymentId } = await feature(db, jobId, userId);
      const event = paymentEvent(paymentId);
      await assert.rejects(db.begin(async (tx) => {
        await tx`select public.receive_asaas_billing_event(${
          tx.json(event)
        }::jsonb)`;
        throw new Error("connection interrupted before commit");
      }));
      const [inbox] =
        await db`select count(*)::int count from public.billing_events`;
      assert.equal(inbox.count, 0);
      assert.equal((await receive(db, event)).status, "processed");
      await assertFeature(db, jobId, 7);
    },
  );
}
