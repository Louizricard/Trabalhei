import assert from "node:assert/strict";
import { customer, type Database, reset } from "../webhook/fixtures.ts";
import { runCheckout } from "../../functions/_shared/checkout.ts";
import {
  featureCheckout,
  proCheckout,
} from "../../functions/_shared/checkout_products.ts";
import { adapter } from "./adapter.ts";
import { Provider } from "./provider.ts";
const body = { billing_type: "PIX", cpf_cnpj: "00000000000" };
export async function moreTests(t: Deno.TestContext, db: Database) {
  await t.step(
    "checkout: dois produtos compartilham um único cliente após timeout",
    async () => {
      await reset(db);
      const { userId, jobId } = await customer(db);
      const provider = new Provider();
      provider.loseResponse = "/customers";
      const { client } = adapter(db);
      await assert.rejects(() =>
        runCheckout(
          client,
          { id: userId },
          "pro_monthly",
          body,
          proCheckout,
          provider.fetch,
        )
      );
      await runCheckout(
        client,
        { id: userId },
        "job_feature",
        { ...body, job_id: jobId },
        featureCheckout,
        provider.fetch,
      );
      await runCheckout(
        client,
        { id: userId },
        "pro_monthly",
        body,
        proCheckout,
        provider.fetch,
      );
      assert.equal(provider.posts["/customers"], 1);
    },
  );
  for (const product of ["pro_monthly", "job_feature"]) {
    await t.step(
      `checkout ${product}: cupom gratuito e benefício são atômicos e idempotentes`,
      async () => {
        await reset(db);
        const { userId, jobId } = await customer(db);
        const code = product === "pro_monthly" ? "TESTPRO" : "TESTFEATURE";
        await db`insert into public.coupons(code,product,percent_off) values(${code},${product},100)`;
        const provider = new Provider();
        const { client } = adapter(db);
        const run = () =>
          runCheckout(
            client,
            { id: userId },
            product,
            { ...body, job_id: jobId, coupon_code: code },
            product === "pro_monthly" ? proCheckout : featureCheckout,
            provider.fetch,
          );
        const first = await run();
        const second = await run();
        assert.deepEqual(second, first);
        assert.equal(first.granted, true);
        assert.deepEqual(provider.posts, {});
        const [count] =
          await db`select count(*)::int n from public.coupon_redemptions where user_id=${userId}`;
        assert.equal(count.n, 1);
      },
    );
  }
  await t.step(
    "checkout: invasor não reserva vaga alheia e papéis públicos não acessam diário/RPC",
    async () => {
      await reset(db);
      const owner = await customer(db);
      const other = await customer(db);
      await assert.rejects(
        () =>
          db`select public.claim_billing_checkout(${other.userId},'job_feature',${owner.jobId},'PIX','')`,
        /JOB_NOT_OPEN/,
      );
      for (const role of ["anon", "authenticated"]) {
        for (
          const query of [
            "select * from public.billing_checkout_steps",
            "select * from public.billing_checkouts",
            `select public.claim_billing_checkout('${owner.userId}','pro_monthly',null,'PIX','')`,
          ]
        ) {
          await assert.rejects(() =>
            db.begin(async (tx) => {
              await tx.unsafe(`set local role ${role}`);
              await tx.unsafe(query);
            }), { code: "42501" });
        }
      }
      await db.begin(async (tx) => {
        await tx`set local role service_role`;
        const [row] =
          await tx`select public.claim_billing_checkout(${owner.userId},'pro_monthly',null,'PIX','') result`;
        await tx`select public.price_billing_checkout(${row.result.checkout.id},${row.result.token})`;
      });
    },
  );
}
