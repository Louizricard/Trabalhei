import assert from "node:assert/strict";
import {
  asUser,
  customer,
  type Database,
  reset,
  sqlFile,
} from "../webhook/fixtures.ts";
import { hired } from "../hiring/fixtures.ts";
import {
  makePro,
  prepareStorage,
  setJobAttachments,
  stored,
  uploadLimitsMigration,
} from "./fixtures.ts";

export async function uploadLimitTests(t: Deno.TestContext, db: Database) {
  await prepareStorage(db);
  await sqlFile(db, `migrations/${uploadLimitsMigration}.sql`);

  await t.step("limites: rollback e reaplicação limpos", async () => {
    await sqlFile(db, `rollbacks/${uploadLimitsMigration}_down.sql`);
    const [old] = await db`select file_size_limit from storage.buckets
      where id='job_attachments'`;
    assert.equal(Number(old.file_size_limit), 20 * 1024 * 1024);
    await sqlFile(db, `migrations/${uploadLimitsMigration}.sql`);
    const [now] = await db`select file_size_limit from storage.buckets
      where id='job_attachments'`;
    assert.equal(Number(now.file_size_limit), 50 * 1024 * 1024);
  });

  await t.step("limites: plano grátis recusa arquivo acima de 10 MB", async () => {
    await reset(db);
    const { userId, jobId } = await customer(db);
    const ok = await stored(db, userId, "job_attachments", 9);
    const big = await stored(db, userId, "job_attachments", 11);
    await setJobAttachments(db, userId, jobId, [ok]);
    await assert.rejects(
      setJobAttachments(db, userId, jobId, [ok, big]),
      /FILE_TOO_LARGE/,
    );
  });

  await t.step("limites: Pro aceita até 50 MB e expirado volta ao grátis", async () => {
    await reset(db);
    const { userId, jobId } = await customer(db);
    const big = await stored(db, userId, "job_attachments", 40);
    await makePro(db, userId);
    await setJobAttachments(db, userId, jobId, [big]);
    await makePro(db, userId, false);
    // Anexo já gravado continua; um novo do mesmo tamanho é recusado.
    const other = await stored(db, userId, "job_attachments", 40);
    await setJobAttachments(db, userId, jobId, [big]);
    await assert.rejects(
      setJobAttachments(db, userId, jobId, [big, other]),
      /FILE_TOO_LARGE/,
    );
  });

  await t.step("limites: anexo de outro usuário, inexistente ou demais", async () => {
    await reset(db);
    const a = await customer(db), b = await customer(db);
    const foreign = await stored(db, b.userId, "job_attachments");
    await assert.rejects(
      setJobAttachments(db, a.userId, a.jobId, [foreign]),
      /ATTACHMENT_NOT_OWNED/,
    );
    const ghost = { ...(await stored(db, a.userId, "job_attachments")) };
    ghost.url = ghost.url.replace("arquivo.pdf", "sumiu.pdf");
    await assert.rejects(
      setJobAttachments(db, a.userId, a.jobId, [ghost]),
      /ATTACHMENT_NOT_FOUND/,
    );
    await assert.rejects(
      setJobAttachments(db, a.userId, a.jobId, [{ url: "https://exemplo.com/x.pdf" }]),
      /ATTACHMENT_INVALID/,
    );
    const six = [];
    for (let i = 0; i < 6; i++) six.push(await stored(db, a.userId, "job_attachments"));
    await assert.rejects(
      setJobAttachments(db, a.userId, a.jobId, six),
      /ATTACHMENT_LIMIT/,
    );
  });

  await t.step("limites: entrega e mensagem também validam o plano", async () => {
    await reset(db);
    const h = await hired(db, [{ title: "Única", amount: 100, days: 3 }]);
    const big = await stored(db, h.worker, "chat_attachments", 11);
    await assert.rejects(
      asUser(db, h.worker, (tx) =>
        tx`select public.submit_deliverable(${h.milestones[0]},'Entrega',${
          tx.json([big] as never)
        })`),
      /FILE_TOO_LARGE/,
    );
    const ok = await stored(db, h.worker, "chat_attachments", 2);
    await asUser(db, h.worker, (tx) =>
      tx`select public.submit_deliverable(${h.milestones[0]},'Entrega',${
        tx.json([ok] as never)
      })`);
    const [conv] = await db`select id from public.conversations
      where freelancer_id=${h.worker} limit 1`;
    await assert.rejects(
      asUser(db, h.worker, (tx) =>
        tx`insert into public.messages
          (conversation_id,sender_id,content,message_type,attachment_url)
          values (${conv.id},${h.worker},'',${"file"},${big.url})`),
      /FILE_TOO_LARGE/,
    );
  });
}
