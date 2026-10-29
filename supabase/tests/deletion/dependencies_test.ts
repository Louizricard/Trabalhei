import assert from "node:assert/strict";
import { deletionDependencies } from "../../functions/delete-account/dependencies.ts";
import {
  asaas,
  AsaasError,
  HttpError,
  requireUser,
} from "../../functions/_shared/common.ts";

async function withApi(
  run: (
    state: { deleted: boolean; profileError: boolean; urls: string[] },
  ) => Promise<void>,
) {
  const keys = {
    SUPABASE_URL: "https://test.invalid",
    SUPABASE_SERVICE_ROLE_KEY: "test-server",
    SUPABASE_ANON_KEY: "test-public",
    ASAAS_API_KEY: "test-provider",
  };
  const saved = Object.fromEntries(
    Object.keys(keys).map((k) => [k, Deno.env.get(k)]),
  );
  for (const [k, v] of Object.entries(keys)) Deno.env.set(k, v);
  const original = globalThis.fetch,
    state = { deleted: false, profileError: false, urls: [] as string[] };
  globalThis.fetch = (input) => {
    const url = String(input);
    state.urls.push(url);
    if (url.includes("/auth/v1/user")) {
      return Promise.resolve(
        Response.json({
          id: "11111111-1111-4111-8111-111111111111",
          aud: "authenticated",
          role: "authenticated",
        }),
      );
    }
    if (url.includes("/rest/v1/profiles")) {
      return Promise.resolve(
        state.profileError
          ? Response.json({ message: "failure" }, { status: 500 })
          : Response.json({ deleted_at: state.deleted ? "2026-10-29" : null }),
      );
    }
    return Promise.resolve(
      new Response("provider-private-detail", { status: 404 }),
    );
  };
  try {
    await run(state);
  } finally {
    globalThis.fetch = original;
    for (const [k, v] of Object.entries(saved)) {
      if (v === undefined) Deno.env.delete(k);
      else Deno.env.set(k, v);
    }
  }
}
function request(
  token = "user-session",
  target = "22222222-2222-4222-8222-222222222222",
) {
  return new Request("https://test.invalid/delete-account", {
    method: "POST",
    headers: { authorization: `Bearer ${token}` },
    body: JSON.stringify({ user_id: target }),
  });
}
Deno.test("exclusão adapter: usuário comum só exclui a própria conta e operador valida alvo", async () => {
  await withApi(async () => {
    const deps = deletionDependencies();
    assert.equal(
      await deps.authorize(request()),
      "11111111-1111-4111-8111-111111111111",
    );
    assert.equal(
      await deps.authorize(request("test-server")),
      "22222222-2222-4222-8222-222222222222",
    );
    await assert.rejects(
      () => deps.authorize(request("test-server", "invalid")),
      /Identificador inválido/,
    );
  });
});
Deno.test("exclusão adapter: cobrança recusa conta fechada mas exclusão permite retomar", async () => {
  await withApi(async (s) => {
    assert.equal(
      (await requireUser(request())).id,
      "11111111-1111-4111-8111-111111111111",
    );
    s.deleted = true;
    await assert.rejects(
      () => requireUser(request()),
      (e) => e instanceof HttpError && e.status === 401,
    );
    assert.ok(await requireUser(request(), true));
    s.profileError = true;
    await assert.rejects(
      () => requireUser(request(), true),
      (e) => e instanceof HttpError && e.status === 503,
    );
  });
});
Deno.test("exclusão adapter: erro do Asaas preserva status sem expor corpo privado", async () => {
  await withApi(async () => {
    await assert.rejects(
      () => asaas("/subscriptions/test", { method: "DELETE" }),
      (e) =>
        e instanceof AsaasError && e.providerStatus === 404 &&
        !e.message.includes("private"),
    );
  });
});
