import assert from "node:assert/strict";
import {
  type GooglePlay,
  googlePlay,
  mapSubscriptionState,
  PlayApiError,
  type PlayProduct,
  type PlaySubscription,
} from "../../functions/_shared/google_play.ts";
import {
  handleNotification,
  type PlayDeps,
  PurchaseError,
  verifyFromApp,
} from "../../functions/_shared/play_purchases.ts";

const USER = "11111111-1111-4111-8111-111111111111";
const OTHER = "22222222-2222-4222-8222-222222222222";
const JOB = "33333333-3333-4333-8333-333333333333";

function fake(
  sub: Partial<PlaySubscription> = {},
  prod: Partial<PlayProduct> = {},
) {
  const calls: string[] = [];
  const rpcs: Array<[string, Record<string, unknown>]> = [];
  const play: GooglePlay = {
    subscription: (t) => {
      calls.push(`sub:${t}`);
      if (t === "missing") return Promise.reject(new PlayApiError(410, "x"));
      return Promise.resolve({
        state: "active",
        productId: "pro_monthly",
        expiresAt: "2030-01-01T00:00:00Z",
        accountId: USER,
        orderId: "GPA.1",
        needsAck: true,
        ...sub,
      });
    },
    acknowledgeSubscription: (
      p,
      t,
    ) => (calls.push(`ack:${p}:${t}`), Promise.resolve()),
    cancelSubscription: (
      p,
      t,
    ) => (calls.push(`cancel:${p}:${t}`), Promise.resolve()),
    product: (p, t) => {
      calls.push(`prod:${p}:${t}`);
      return Promise.resolve({
        purchaseState: 0,
        accountId: USER,
        profileId: JOB,
        orderId: "GPA.2",
        consumed: false,
        ...prod,
      });
    },
    consumeProduct: (
      p,
      t,
    ) => (calls.push(`consume:${p}:${t}`), Promise.resolve()),
  };
  const deps: PlayDeps = {
    play,
    rpc: (name, args) => {
      rpcs.push([name, args]);
      return Promise.resolve({ state: "ok" });
    },
  };
  return { deps, calls, rpcs };
}

const pubsub = (n: unknown) => ({ message: { data: btoa(JSON.stringify(n)) } });

Deno.test("play: estados do Google viram estados do Trabalhei", () => {
  assert.equal(mapSubscriptionState("SUBSCRIPTION_STATE_ACTIVE"), "active");
  assert.equal(
    mapSubscriptionState("SUBSCRIPTION_STATE_IN_GRACE_PERIOD"),
    "active",
  );
  assert.equal(
    mapSubscriptionState("SUBSCRIPTION_STATE_CANCELED"),
    "cancelled",
  );
  assert.equal(mapSubscriptionState("SUBSCRIPTION_STATE_PENDING"), "pending");
  for (
    const s of [
      "SUBSCRIPTION_STATE_ON_HOLD",
      "SUBSCRIPTION_STATE_PAUSED",
      "SUBSCRIPTION_STATE_EXPIRED",
      "X",
    ]
  ) {
    assert.equal(mapSubscriptionState(s), "expired");
  }
});

Deno.test("play: assinatura do app grava e só então reconhece", async () => {
  const { deps, calls, rpcs } = fake();
  await verifyFromApp(deps, USER, {
    product: "pro_monthly",
    purchase_token: "tok",
  });
  assert.deepEqual(rpcs[0], ["apply_play_subscription", {
    p_user: USER,
    p_token: "tok",
    p_order: "GPA.1",
    p_state: "active",
    p_expires: "2030-01-01T00:00:00Z",
  }]);
  assert.deepEqual(calls, ["sub:tok", "ack:pro_monthly:tok"]);
});

Deno.test("play: compra de outra conta, produto errado ou token inválido são recusados", async () => {
  await assert.rejects(
    verifyFromApp(fake().deps, OTHER, {
      product: "pro_monthly",
      purchase_token: "tok",
    }),
    (e) => e instanceof PurchaseError && e.status === 403,
  );
  await assert.rejects(
    verifyFromApp(fake({ productId: "outro" }).deps, USER, {
      product: "pro_monthly",
      purchase_token: "tok",
    }),
    PurchaseError,
  );
  await assert.rejects(
    verifyFromApp(fake({ accountId: null }).deps, USER, {
      product: "pro_monthly",
      purchase_token: "tok",
    }),
    PurchaseError,
  );
  await assert.rejects(
    verifyFromApp(fake().deps, USER, {
      product: "pro_monthly",
      purchase_token: "missing",
    }),
    (e) => e instanceof PurchaseError && e.status === 400,
  );
  await assert.rejects(
    verifyFromApp(fake().deps, USER, { product: "x", purchase_token: "t" }),
    PurchaseError,
  );
  await assert.rejects(
    verifyFromApp(fake().deps, USER, { product: "pro_monthly" }),
    PurchaseError,
  );
});

Deno.test("play: assinatura pendente não é reconhecida nem ganha prazo", async () => {
  const { deps, calls, rpcs } = fake({ state: "pending" });
  await verifyFromApp(deps, USER, {
    product: "pro_monthly",
    purchase_token: "tok",
  });
  assert.equal(rpcs[0][1].p_expires, null);
  assert.deepEqual(calls, ["sub:tok"]);
});

Deno.test("play: destaque usa a vaga gravada no Google e consome depois de aplicar", async () => {
  const { deps, calls, rpcs } = fake();
  await verifyFromApp(deps, USER, {
    product: "job_feature",
    purchase_token: "f1",
    job_id: "ignorado",
  });
  assert.deepEqual(rpcs[0], ["apply_play_feature", {
    p_user: USER,
    p_token: "f1",
    p_order: "GPA.2",
    p_job: JOB,
  }]);
  assert.deepEqual(calls, ["prod:job_feature:f1", "consume:job_feature:f1"]);
});

Deno.test("play: destaque pendente espera; cancelado ou sem vaga é recusado", async () => {
  const pending = fake({}, { purchaseState: 2 });
  assert.deepEqual(
    await verifyFromApp(pending.deps, USER, {
      product: "job_feature",
      purchase_token: "f",
    }),
    {
      state: "pending",
    },
  );
  assert.equal(pending.rpcs.length, 0);
  await assert.rejects(
    verifyFromApp(fake({}, { purchaseState: 1 }).deps, USER, {
      product: "job_feature",
      purchase_token: "f",
    }),
    PurchaseError,
  );
  await assert.rejects(
    verifyFromApp(fake({}, { profileId: null }).deps, USER, {
      product: "job_feature",
      purchase_token: "f",
    }),
    PurchaseError,
  );
});

Deno.test("play: notificações de renovação, estorno, compra avulsa e outros apps", async () => {
  const pkg = "com.trabalhei.app";
  let f = fake({ state: "cancelled", needsAck: false });
  assert.equal(
    await handleNotification(
      f.deps,
      pubsub({
        packageName: pkg,
        subscriptionNotification: { purchaseToken: "s1" },
      }),
    ),
    "subscription",
  );
  assert.equal(f.rpcs[0][1].p_state, "cancelled");
  assert.deepEqual(f.calls, ["sub:s1"]);

  f = fake();
  assert.equal(
    await handleNotification(
      f.deps,
      pubsub({
        packageName: pkg,
        voidedPurchaseNotification: { purchaseToken: "v1" },
      }),
    ),
    "revoked",
  );
  assert.deepEqual(f.rpcs, [["revoke_play_purchase", { p_token: "v1" }]]);

  f = fake();
  assert.equal(
    await handleNotification(
      f.deps,
      pubsub({
        packageName: pkg,
        oneTimeProductNotification: {
          purchaseToken: "o1",
          notificationType: 1,
          sku: "job_feature",
        },
      }),
    ),
    "feature",
  );
  assert.equal(f.rpcs[0][0], "apply_play_feature");

  f = fake();
  assert.equal(
    await handleNotification(
      f.deps,
      pubsub({
        packageName: "outro.app",
        voidedPurchaseNotification: { purchaseToken: "v" },
      }),
    ),
    "ignored",
  );
  assert.equal(
    await handleNotification(
      f.deps,
      pubsub({ packageName: pkg, testNotification: {} }),
    ),
    "test",
  );
  assert.equal(f.rpcs.length, 0);
  await assert.rejects(
    handleNotification(f.deps, { message: { data: "%%%" } }),
    PurchaseError,
  );
});

Deno.test("play: cliente real assina o JWT, guarda o token e monta as URLs do Google", async () => {
  const { privateKey } = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const der = new Uint8Array(
    await crypto.subtle.exportKey("pkcs8", privateKey),
  );
  const pem = `-----BEGIN PRIVATE KEY-----\n${
    btoa(String.fromCharCode(...der))
  }\n-----END PRIVATE KEY-----\n`;
  const seen: string[] = [];
  const request = ((url: string, init: RequestInit) => {
    seen.push(`${init.method} ${url}`);
    if (url.includes("oauth2")) {
      const assertion = new URLSearchParams(String(init.body)).get(
        "assertion",
      )!;
      assert.equal(assertion.split(".").length, 3);
      return Promise.resolve(
        Response.json({ access_token: "at", expires_in: 3600 }),
      );
    }
    assert.equal(
      (init.headers as Record<string, string>).Authorization,
      "Bearer at",
    );
    return Promise.resolve(Response.json({
      subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
      acknowledgementState: "ACKNOWLEDGEMENT_STATE_PENDING",
      externalAccountIdentifiers: { obfuscatedExternalAccountId: USER },
      lineItems: [{
        productId: "pro_monthly",
        expiryTime: "2030-01-01T00:00:00Z",
      }],
      latestOrderId: "GPA.9",
    }));
  }) as typeof fetch;
  const play = googlePlay(
    JSON.stringify({
      client_email: "sa@x.iam.gserviceaccount.com",
      private_key: pem,
    }),
    request,
  );
  const s = await play.subscription("a/b");
  assert.deepEqual(s, {
    state: "active",
    productId: "pro_monthly",
    expiresAt: "2030-01-01T00:00:00Z",
    accountId: USER,
    orderId: "GPA.9",
    needsAck: true,
  });
  await play.acknowledgeSubscription("pro_monthly", "a/b");
  assert.equal(
    seen.filter((u) => u.includes("oauth2")).length,
    1,
    "token de acesso reaproveitado",
  );
  assert.ok(seen.includes(
    "GET https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.trabalhei.app/purchases/subscriptionsv2/tokens/a%2Fb",
  ));
  assert.ok(
    seen.some((u) =>
      u.endsWith("purchases/subscriptions/pro_monthly/tokens/a%2Fb:acknowledge")
    ),
  );
});
