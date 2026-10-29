import assert from "node:assert/strict";
import {
  createWebhookHandler,
  type ProcessingResult,
} from "../../functions/asaas-webhook/handler.ts";

function fixture(receive: () => Promise<ProcessingResult>) {
  let calls = 0;
  const handler = createWebhookHandler({
    token: () => "test-token",
    receive: () => {
      calls++;
      return receive();
    },
    reply: (body, status = 200) => Response.json(body, { status }),
    report: () => Promise.resolve(),
  });
  const request = (
    body: unknown = { id: "evt-test", event: "PAYMENT_CREATED" },
    token = "test-token",
  ) =>
    handler(
      new Request("https://example.invalid/webhook", {
        method: "POST",
        headers: { "asaas-access-token": token },
        body: JSON.stringify(body),
      }),
    );
  return { handler, request, calls: () => calls };
}

Deno.test("webhook: recusa token inválido antes de acessar o banco", async () => {
  const f = fixture(() => Promise.resolve({ status: "processed" }));
  assert.equal((await f.request(undefined, "wrong")).status, 401);
  assert.equal(f.calls(), 0);
});

Deno.test("webhook: rejeita corpo inválido e pagamento sem id", async () => {
  const f = fixture(() => Promise.resolve({ status: "processed" }));
  for (
    const body of [null, [], { id: 1, event: "x" }, {
      id: "e",
      event: "PAYMENT_RECEIVED",
    }]
  ) {
    assert.equal((await f.request(body)).status, 400);
  }
  assert.equal(f.calls(), 0);
});

Deno.test("webhook: só responde 200 para evento concluído ou ignorado", async () => {
  for (const status of ["processed", "ignored", "legacy"] as const) {
    const f = fixture(() => Promise.resolve({ status, duplicate: true }));
    const response = await f.request();
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { ok: true, duplicate: true });
  }
});

Deno.test("webhook: ausência de vínculo e falhas pedem reenvio", async () => {
  for (const status of ["pending", "failed"] as const) {
    const f = fixture(() => Promise.resolve({ status }));
    assert.equal((await f.request()).status, 503);
  }
});

Deno.test("webhook: erro de RPC e resposta inválida nunca recebem confirmação", async () => {
  const failure = fixture(() => Promise.reject(new Error("connection lost")));
  assert.equal((await failure.request()).status, 500);
  const malformed = fixture(() =>
    Promise.resolve(null as unknown as ProcessingResult)
  );
  assert.equal((await malformed.request()).status, 500);
});

Deno.test("webhook: GET não executa processamento e OPTIONS continua disponível", async () => {
  const f = fixture(() => Promise.resolve({ status: "processed" }));
  assert.equal(
    (await f.handler(new Request("https://example.invalid"))).status,
    405,
  );
  assert.equal(
    (await f.handler(
      new Request("https://example.invalid", { method: "OPTIONS" }),
    )).status,
    200,
  );
  assert.equal(f.calls(), 0);
});
