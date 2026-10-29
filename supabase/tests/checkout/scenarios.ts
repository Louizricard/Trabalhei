import { moreTests } from "./extras.ts";
import { recoveryTests } from "./recovery.ts";
import assert from "node:assert/strict";
import {
  customer,
  type Database,
  reset,
  sqlFile,
} from "../webhook/fixtures.ts";
import { runCheckout } from "../../functions/_shared/checkout.ts";
import {
  featureCheckout,
  proCheckout,
} from "../../functions/_shared/checkout_products.ts";
import { adapter } from "./adapter.ts";
import { Provider } from "./provider.ts";

export const reservations = "20261029162532_billing_checkout_reservations";
export const effects = "20261029162534_billing_checkout_effects";
const body = { billing_type: "PIX", cpf_cnpj: "00000000000" };

export async function checkoutTests(t: Deno.TestContext, db: Database) {
  await reset(db);
  await sqlFile(db, `migrations/${reservations}.sql`);
  await sqlFile(db, `migrations/${effects}.sql`);
  // Supabase fornece estes privilégios gerenciados; o PostgreSQL descartável não.
  await db`grant all on all tables in schema public to service_role`;
  Deno.env.set("ASAAS_API_KEY", "test-only-not-a-real-key");
  await t.step(
    "checkout: rollbacks preservam diário e reaplicam migrations",
    async () => {
      await db.begin(async (tx) => {
        await sqlFile(
          tx as unknown as Database,
          `rollbacks/${effects}_down.sql`,
        );
      });
      await sqlFile(db, `rollbacks/${reservations}_down.sql`);
      await sqlFile(db, `migrations/${reservations}.sql`);
      await sqlFile(db, `migrations/${effects}.sql`);
    },
  );
  for (const product of ["pro_monthly", "job_feature"]) {
    await t.step(
      `checkout ${product}: concorrência e retomada criam uma única cobrança`,
      async () => {
        await reset(db);
        const { userId, jobId } = await customer(db);
        const provider = new Provider();
        const { client } = adapter(db);
        const run = () =>
          runCheckout(
            client,
            { id: userId },
            product,
            { ...body, job_id: jobId },
            product === "pro_monthly" ? proCheckout : featureCheckout,
            provider.fetch,
          );
        const results = await Promise.allSettled(
          Array.from({ length: 12 }, run),
        );
        assert.ok(results.some((r) => r.status === "fulfilled"));
        const result = await run();
        assert.ok(result.pix);
        assert.equal(provider.posts["/customers"], 1);
        assert.equal(
          provider
            .posts[product === "pro_monthly" ? "/subscriptions" : "/payments"],
          1,
        );
        const card = await runCheckout(
          client,
          { id: userId },
          product,
          { ...body, billing_type: "CREDIT_CARD", job_id: jobId },
          product === "pro_monthly" ? proCheckout : featureCheckout,
          provider.fetch,
        );
        assert.equal(card.payment_id, result.payment_id);
        assert.ok(card.invoice_url);
        assert.equal(card.pix, undefined);
        assert.equal(
          provider
            .posts[product === "pro_monthly" ? "/subscriptions" : "/payments"],
          1,
        );
      },
    );
    for (
      const point of [
        "provider",
        "record_billing_step",
        "link_billing_checkout",
      ]
    ) {
      await t.step(
        `checkout ${product}: recupera falha em ${point} sem novo POST`,
        async () => {
          await reset(db);
          const { userId, jobId } = await customer(db);
          const provider = new Provider();
          const { client, failures } = adapter(db);
          const resource = product === "pro_monthly"
            ? "/subscriptions"
            : "/payments";
          provider.beforeReturn = async (path) => {
            if (path !== resource) return;
            provider.beforeReturn = undefined;
            if (point !== "provider") failures.add(point);
          };
          if (point === "provider") provider.loseResponse = resource;
          const run = () =>
            runCheckout(
              client,
              { id: userId },
              product,
              { ...body, job_id: jobId },
              product === "pro_monthly" ? proCheckout : featureCheckout,
              provider.fetch,
            );
          await assert.rejects(run);
          const result = await run();
          assert.ok(result.payment_id);
          assert.equal(provider.posts[resource], 1);
        },
      );
    }
  }
  await t.step(
    "checkout: resultado inconclusivo vazio não autoriza recriação mesmo após expiração",
    async () => {
      await reset(db);
      const { userId, jobId } = await customer(db);
      const provider = new Provider();
      const { client } = adapter(db);
      // O POST pode não chegar ao provedor; não há como afirmar que ele não criou.
      const broken: typeof fetch = async (input, init) => {
        if (String(input).endsWith("/payments") && init?.method === "POST") {
          throw new TypeError("Connection lost");
        }
        return await provider.fetch(input, init);
      };
      const run = (request: typeof fetch) =>
        runCheckout(
          client,
          { id: userId },
          "job_feature",
          { ...body, job_id: jobId },
          featureCheckout,
          request,
        );
      await assert.rejects(() => run(broken));
      await db`update public.billing_checkout_locks set expires_at=now()-interval '1 day'`;
      await assert.rejects(() => run(provider.fetch), /conciliação/);
      assert.equal(provider.posts["/payments"], undefined);
    },
  );
  await moreTests(t, db);
  await recoveryTests(t, db);
}
