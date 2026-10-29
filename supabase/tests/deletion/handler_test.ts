import assert from "node:assert/strict";
import { createDeletionHandler } from "../../functions/delete-account/handler.ts";
import {
  type DeletionDependencies,
  DeletionError,
} from "../../functions/delete-account/workflow.ts";

function fixture() {
  const calls: string[] = [];
  const deps: DeletionDependencies = {
    authorize: () => Promise.resolve("own-user"),
    begin: (u) => {
      calls.push(u);
      return Promise.resolve({
        token: "t",
        hard_delete: true,
        phase: "storage",
      });
    },
    cancelBilling: () => Promise.resolve(),
    objects: () => Promise.resolve([]),
    remove: () => Promise.resolve(),
    prepareAuth: () => Promise.resolve(),
    eraseAuth: () => {
      calls.push("auth");
      return Promise.resolve();
    },
    complete: () => Promise.resolve(),
    fail: () => Promise.resolve(),
    report: () => Promise.resolve(),
    reply: (body, status = 200) => Response.json(body, { status }),
  };
  return {
    deps,
    calls,
    request: (method = "POST") =>
      createDeletionHandler(deps)(
        new Request("https://example.invalid/delete-account", { method }),
      ),
  };
}
Deno.test("exclusão HTTP: autenticação e métodos são obrigatórios", async () => {
  const f = fixture();
  assert.equal((await f.request("GET")).status, 405);
  assert.equal((await f.request("OPTIONS")).status, 200);
  f.deps.authorize = () =>
    Promise.reject(new DeletionError(401, "Sessão inválida."));
  assert.equal((await f.request()).status, 401);
  assert.deepEqual(f.calls, []);
});
Deno.test("exclusão HTTP: não retorna sucesso com manifesto inválido ou sem progresso", async () => {
  for (
    const result of [null, [{ bucket_id: "resumes", name: "own-user/cv.pdf" }]]
  ) {
    const f = fixture();
    f.deps.objects = () => Promise.resolve(result as never);
    assert.equal((await f.request()).status, 503);
    assert.equal(f.calls.includes("auth"), false);
  }
});
Deno.test("exclusão HTTP: recusa concorrência e esconde detalhes internos", async () => {
  const f = fixture();
  f.deps.begin = () => Promise.reject(new DeletionError(409, "Em andamento."));
  assert.equal((await f.request()).status, 409);
  f.deps.begin = () => Promise.reject(new Error("private-credential"));
  const r = await f.request();
  assert.equal(r.status, 503);
  assert.ok(!(await r.text()).includes("private-credential"));
});
Deno.test("exclusão HTTP: sucesso exige Auth e conclusão do pedido", async () => {
  const f = fixture();
  let complete = false;
  f.deps.complete = () => {
    complete = true;
    return Promise.resolve();
  };
  assert.equal((await f.request()).status, 200);
  assert.ok(complete);
  assert.deepEqual(f.calls, ["own-user", "auth"]);
});
