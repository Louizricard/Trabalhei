import assert from "node:assert/strict";
import {
  type CleanupDependencies,
  createCleanupHandler,
  type StoredPath,
} from "../../functions/storage-cleanup/handler.ts";

function fixture(failBucket?: string) {
  const removed: string[] = [];
  let reported: { done: StoredPath[]; failed: StoredPath[] } | null = null;
  const deps: CleanupDependencies = {
    authorize: (req) => Promise.resolve(req.headers.get("authorization") === "Bearer ok"),
    batch: () =>
      Promise.resolve([
        { bucket: "job_attachments", path: "u/a.pdf" },
        { bucket: "job_covers", path: "u/c.png" },
        { bucket: "job_attachments", path: "u/b.pdf" },
      ]),
    remove: (bucket, paths) => {
      if (bucket === failBucket) return Promise.reject(new Error("storage fora"));
      removed.push(...paths.map((p) => `${bucket}/${p}`));
      return Promise.resolve();
    },
    report: (done, failed) => {
      reported = { done, failed };
      return Promise.resolve();
    },
    reply: (body, status = 200) => Response.json(body, { status }),
  };
  return { deps, removed, reported: () => reported };
}

const post = (auth: string) =>
  new Request("http://x", { method: "POST", headers: { authorization: auth } });

Deno.test("limpeza: recusa chamada sem a chave de serviço", async () => {
  const f = fixture();
  const res = await createCleanupHandler(f.deps)(post("Bearer anon"));
  assert.equal(res.status, 401);
  assert.deepEqual(f.removed, []);
  assert.equal((await createCleanupHandler(f.deps)(new Request("http://x"))).status, 405);
});

Deno.test("limpeza: apaga por bucket e relata o resultado", async () => {
  const f = fixture();
  const res = await createCleanupHandler(f.deps)(post("Bearer ok"));
  assert.deepEqual(await res.json(), { removed: 3, failed: 0 });
  assert.deepEqual(f.removed.sort(), ["job_attachments/u/a.pdf", "job_attachments/u/b.pdf", "job_covers/u/c.png"]);
});

Deno.test("limpeza: falha em um bucket não impede os outros", async () => {
  const f = fixture("job_covers");
  const res = await createCleanupHandler(f.deps)(post("Bearer ok"));
  assert.deepEqual(await res.json(), { removed: 2, failed: 1 });
  assert.deepEqual(f.reported()?.failed, [{ bucket: "job_covers", path: "u/c.png" }]);
});
