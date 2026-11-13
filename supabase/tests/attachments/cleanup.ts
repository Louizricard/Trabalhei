import assert from "node:assert/strict";
import { customer, type Database, reset, sqlFile } from "../webhook/fixtures.ts";
import { setJobAttachments, stored } from "./fixtures.ts";

export const cleanupMigration = "20261113185537_storage_cleanup_queue";

async function clean(db: Database) {
  await reset(db);
  await db`delete from public.storage_cleanup_queue`;
  await db`delete from storage.objects where bucket_id in ('job_attachments','job_covers')`;
}

async function batch(db: Database, grace = "1 day") {
  const rows = await db`select bucket, path from public.storage_cleanup_batch(100, ${grace}::interval)`;
  return rows.map((r) => `${r.bucket}/${r.path}`).sort();
}

const key = (item: { url: string }) =>
  item.url.split("/storage/v1/object/public/")[1];

export async function cleanupTests(t: Deno.TestContext, db: Database) {
  await db`alter table storage.objects add column if not exists created_at timestamptz not null default now()`;
  await sqlFile(db, `migrations/${cleanupMigration}.sql`);

  await t.step("limpeza: rollback e reaplicação limpos", async () => {
    await sqlFile(db, `rollbacks/${cleanupMigration}_down.sql`);
    await sqlFile(db, `migrations/${cleanupMigration}.sql`);
  });

  await t.step("limpeza: anexo removido ou vaga apagada entram na fila", async () => {
    await clean(db);
    const { userId, jobId } = await customer(db);
    const keep = await stored(db, userId, "job_attachments");
    const drop = await stored(db, userId, "job_attachments");
    await setJobAttachments(db, userId, jobId, [keep, drop]);
    await setJobAttachments(db, userId, jobId, [keep]);
    assert.deepEqual(await batch(db), [key(drop)]);
    await db`delete from public.jobs where id=${jobId}`;
    assert.deepEqual(await batch(db), [key(drop), key(keep)].sort());
  });

  await t.step("limpeza: órfão só depois da carência e nunca se voltar a ser usado", async () => {
    await clean(db);
    const { userId, jobId } = await customer(db);
    const orphan = await stored(db, userId, "job_attachments");
    const used = await stored(db, userId, "job_attachments");
    await setJobAttachments(db, userId, jobId, [used]);
    assert.deepEqual(await batch(db), []);
    await db`update storage.objects set created_at=now()-interval '2 days'`;
    assert.deepEqual(await batch(db), [key(orphan)]);
    await db`insert into public.storage_cleanup_queue (bucket,path,reason)
      values ('job_attachments', ${key(used).replace("job_attachments/", "")}, 'teste')`;
    assert.deepEqual(await batch(db), [key(orphan)]);
  });

  await t.step("limpeza: relatório tira da fila e conta falhas", async () => {
    await db`delete from public.storage_cleanup_queue`;
    await db`insert into public.storage_cleanup_queue (bucket,path,reason) values
      ('job_attachments','a/x.pdf','teste'), ('job_attachments','a/y.pdf','teste')`;
    await db`select public.storage_cleanup_report(
      ${db.json([{ bucket: "job_attachments", path: "a/x.pdf" }])},
      ${db.json([{ bucket: "job_attachments", path: "a/y.pdf" }])}, 'falhou')`;
    const rows = await db`select path, attempts from public.storage_cleanup_queue`;
    assert.deepEqual(rows.map((r) => [r.path, r.attempts]), [["a/y.pdf", 1]]);
    await db`delete from public.storage_cleanup_queue`;
  });
}
