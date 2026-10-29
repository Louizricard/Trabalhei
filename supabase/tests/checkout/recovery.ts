import assert from "node:assert/strict";
import { customer, type Database, reset } from "../webhook/fixtures.ts";
import { Checkout, runCheckout } from "../../functions/_shared/checkout.ts";
import {
  featureCheckout,
  proCheckout,
} from "../../functions/_shared/checkout_products.ts";
import { adapter } from "./adapter.ts";
import { Provider } from "./provider.ts";
const body = { billing_type: "PIX", cpf_cnpj: "00000000000" };

export async function recoveryTests(t: Deno.TestContext, db: Database) {
  await t.step(
    "checkout: lease vencida não permite que worker antigo reserve outro POST ou libere a nova lease",
    async () => {
      await reset(db);
      const { userId } = await customer(db);
      const { client } = adapter(db);
      const claim = () =>
        client.rpc("claim_billing_checkout", {
          p_user: userId,
          p_product: "pro_monthly",
          p_job: null,
          p_billing_type: "PIX",
          p_coupon: "",
        });
      const first = (await claim()).data;
      await db`update public.billing_checkout_locks set expires_at=now()-interval '1 second'`;
      const second = (await claim()).data;
      const stale = new Checkout(client, first.checkout, first.token, {
        id: userId,
      });
      await assert.rejects(
        () => stale.rpc("reserve_billing_step", { p_key: "forbidden" }),
        /preparado/,
      );
      await client.rpc("release_billing_checkout", {
        p_id: first.checkout.id,
        p_token: first.token,
      });
      const [row] =
        await db`select token from public.billing_checkout_locks where user_id=${userId}`;
      assert.equal(row.token, second.token);
    },
  );
  await t.step(
    "checkout: mesmo request_id após confirmação retoma resultado; nova intenção permite nova compra",
    async () => {
      await reset(db);
      const { userId, jobId } = await customer(db);
      const { client } = adapter(db);
      const provider = new Provider();
      const requestId = crypto.randomUUID();
      const run = (id: string) =>
        runCheckout(
          client,
          { id: userId },
          "job_feature",
          { ...body, job_id: jobId, request_id: id },
          featureCheckout,
          provider.fetch,
        );
      const first = await run(requestId);
      await db`update public.job_featurings set status='paid',paid_at=now() where asaas_payment_id=${first
        .payment_id as string}`;
      assert.equal((await run(requestId)).granted, true);
      assert.equal(provider.posts["/payments"], 1);
      await run(crypto.randomUUID());
      assert.equal(provider.posts["/payments"], 2);
    },
  );
  await t.step(
    "checkout: erro 400 definitivo permite corrigir dados sem prender a operação",
    async () => {
      await reset(db);
      const { userId } = await customer(db);
      const { client } = adapter(db);
      const provider = new Provider();
      let rejected = false;
      const request: typeof fetch = (input, options) => {
        if (!rejected && options?.method === "POST") {
          rejected = true;
          return Promise.resolve(new Response("{}", { status: 400 }));
        }
        return provider.fetch(input, options);
      };
      const run = () =>
        runCheckout(
          client,
          { id: userId },
          "pro_monthly",
          body,
          proCheckout,
          request,
        );
      await assert.rejects(run, /Dados recusados/);
      assert.ok((await run()).payment_id);
      assert.equal(provider.posts["/customers"], 1);
      assert.equal(provider.posts["/subscriptions"], 1);
    },
  );
  await t.step(
    "checkout: falha ao registrar destaque gratuito desfaz cupom e benefício juntos",
    async () => {
      await reset(db);
      const { userId, jobId } = await customer(db);
      const { client } = adapter(db);
      const provider = new Provider();
      await db`insert into public.coupons(code,product,percent_off) values('TESTATOMIC','job_feature',100)`;
      await db.unsafe(
        `create function public.test_reject_free_feature() returns trigger language plpgsql as $$
      begin raise exception 'TEST_FAILURE'; end; $$;
      create trigger test_free_failure before insert on public.job_featurings for each row execute function public.test_reject_free_feature()`,
      );
      const run = () =>
        runCheckout(
          client,
          { id: userId },
          "job_feature",
          { ...body, job_id: jobId, coupon_code: "TESTATOMIC" },
          featureCheckout,
          provider.fetch,
        );
      try {
        await assert.rejects(run);
      } finally {
        await db.unsafe(
          "drop trigger test_free_failure on public.job_featurings; drop function public.test_reject_free_feature()",
        );
      }
      const [row] =
        await db`select featured_until,(select count(*)::int from public.coupon_redemptions where user_id=${userId}) redemptions
      from public.jobs where id=${jobId}`;
      assert.equal(row.featured_until, null);
      assert.equal(row.redemptions, 0);
      assert.equal((await run()).granted, true);
    },
  );
  await t.step(
    "checkout: índices recusam duas assinaturas abertas e dois destaques pendentes",
    async () => {
      await reset(db);
      const { userId, jobId } = await customer(db);
      await db`insert into public.subscriptions(user_id,asaas_subscription_id,billing_type) values(${userId},'test-1','PIX')`;
      await assert.rejects(
        () =>
          db`insert into public.subscriptions(user_id,asaas_subscription_id,billing_type)
      values(${userId},'test-2','PIX')`,
        { code: "23505" },
      );
      await db`insert into public.job_featurings(job_id,user_id,asaas_payment_id,days,amount) values(${jobId},${userId},'test-1',7,9.9)`;
      await assert.rejects(
        () =>
          db`insert into public.job_featurings(job_id,user_id,asaas_payment_id,days,amount)
      values(${jobId},${userId},'test-2',7,9.9)`,
        { code: "23505" },
      );
    },
  );
}
