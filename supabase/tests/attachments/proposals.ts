import assert from "node:assert/strict";
import {
  asUser,
  customer,
  type Database,
  reset,
  sqlFile,
} from "../webhook/fixtures.ts";
import { accept, coverLetter, freelancer } from "../hiring/fixtures.ts";
import { stored } from "./fixtures.ts";

export const portfolioMigration = "20261113120300_proposal_portfolio";
const BUCKET = "proposal_attachments";

function submit(
  db: Database,
  user: string,
  jobId: string,
  files: unknown[] = [],
  links: unknown[] = [],
) {
  return asUser(db, user, async (tx) => {
    const [r] = await tx`select (public.submit_proposal(${jobId},100,7,${coverLetter},
      '[]'::jsonb, ${tx.json(links as never)}, ${tx.json(files as never)})).id`;
    return r.id as string;
  });
}

async function canRead(db: Database, user: string | null, name: string) {
  const query = (tx: Database) =>
    tx`select count(*)::int n from storage.objects where bucket_id=${BUCKET} and name=${name}`;
  const rows = user === null
    ? await db.begin(async (tx) => {
      await tx`set local role anon`;
      return await query(tx as unknown as Database);
    })
    : await asUser(db, user, query);
  return rows[0].n === 1;
}

const pathOf = (item: { url: string }) => item.url.split(`/${BUCKET}/`)[1];

async function scenario(db: Database) {
  await reset(db);
  const client = await customer(db), other = await customer(db);
  const worker = await freelancer(db), rival = await freelancer(db);
  const file = await stored(db, worker, BUCKET, 1, client.jobId);
  const proposalId = await submit(db, worker, client.jobId, [file], ["https://github.com/ana"]);
  return { client, other, worker, rival, file, name: pathOf(file), proposalId };
}

export async function portfolioTests(t: Deno.TestContext, db: Database) {
  await sqlFile(db, `migrations/${portfolioMigration}.sql`);

  await t.step("portfólio: rollback recusa dados e reaplica limpo", async () => {
    await db`delete from storage.objects where bucket_id=${BUCKET}`;
    await reset(db);
    await sqlFile(db, `rollbacks/${portfolioMigration}_down.sql`);
    await sqlFile(db, `migrations/${portfolioMigration}.sql`);
    await scenario(db);
    await assert.rejects(
      sqlFile(db, `rollbacks/${portfolioMigration}_down.sql`),
      /PROPOSAL_PORTFOLIO_DATA_PRESENT/,
    );
  });

  await t.step("portfólio: só autor e dono da vaga leem o anexo", async () => {
    const s = await scenario(db);
    assert.equal(await canRead(db, s.worker, s.name), true);
    assert.equal(await canRead(db, s.client.userId, s.name), true);
    assert.equal(await canRead(db, s.rival, s.name), false);
    assert.equal(await canRead(db, s.other.userId, s.name), false);
    assert.equal(await canRead(db, null, s.name), false);
    const [p] = await db`select portfolio_links from public.proposals where id=${s.proposalId}`;
    assert.deepEqual(p.portfolio_links, ["https://github.com/ana"]);
  });

  await t.step("portfólio: acesso acompanha o estado da vaga e da proposta", async () => {
    const s = await scenario(db);
    await accept(db, s.client.userId, s.proposalId);
    assert.equal(await canRead(db, s.client.userId, s.name), true);
    for (const status of ["completed", "cancelled"]) {
      await db`update public.jobs set status=${status} where id=${s.client.jobId}`;
      assert.equal(await canRead(db, s.client.userId, s.name), true, status);
    }
    const r = await scenario(db);
    await db`update public.proposals set status='rejected' where id=${r.proposalId}`;
    assert.equal(await canRead(db, r.client.userId, r.name), true);
    await db`delete from public.jobs where id=${r.client.jobId}`;
    assert.equal(await canRead(db, r.client.userId, r.name), false);
    const [q] = await db`select count(*)::int n from public.storage_cleanup_queue
      where bucket=${BUCKET} and path=${r.name}`;
    assert.equal(q.n, 1);
  });

  await t.step("portfólio: reenvio sem o anexo tira o acesso e enfileira", async () => {
    const s = await scenario(db);
    await submit(db, s.worker, s.client.jobId, []);
    assert.equal(await canRead(db, s.client.userId, s.name), false);
    assert.equal(await canRead(db, s.worker, s.name), true);
    const [q] = await db`select count(*)::int n from public.storage_cleanup_queue
      where bucket=${BUCKET} and path=${s.name}`;
    assert.equal(q.n, 1);
  });

  await t.step("portfólio: recusa anexo alheio, de outra vaga, grande ou link inválido", async () => {
    const s = await scenario(db);
    const job2 = await customer(db);
    const foreign = await stored(db, s.rival, BUCKET, 1, job2.jobId);
    await assert.rejects(submit(db, s.worker, job2.jobId, [foreign]), /ATTACHMENT_NOT_OWNED/);
    const wrongJob = await stored(db, s.worker, BUCKET, 1, s.client.jobId);
    await assert.rejects(submit(db, s.worker, job2.jobId, [wrongJob]), /ATTACHMENT_INVALID/);
    const big = await stored(db, s.worker, BUCKET, 11, job2.jobId);
    await assert.rejects(submit(db, s.worker, job2.jobId, [big]), /FILE_TOO_LARGE/);
    for (const links of [["ftp://x.com"], ["https://a.com", "https://A.com"], [42]]) {
      await assert.rejects(
        submit(db, s.worker, job2.jobId, [], links),
        /INVALID_PORTFOLIO_LINKS/,
      );
    }
  });
}
