import assert from "node:assert/strict";
import { customer, type Database, reset } from "../webhook/fixtures.ts";
import { begin, contract, object, personalProfile } from "./fixtures.ts";

async function asUser<T>(
  db: Database,
  user: string,
  query: (tx: Database) => Promise<T>,
) {
  return await db.begin(async (tx) => {
    await tx`set local role authenticated`;
    await tx`select set_config('request.jwt.claim.sub',${user},true)`;
    return await query(tx as unknown as Database);
  });
}
export async function accessTests(t: Deno.TestContext, db: Database) {
  await t.step(
    "exclusão: tombstone visível só ao próprio e à contraparte",
    async () => {
      await reset(db);
      const { client, freelancer } = await contract(db);
      const outsider = await customer(db);
      await personalProfile(db, freelancer.userId);
      await begin(db, freelancer.userId);
      for (
        const [viewer, count] of [[freelancer.userId, 1], [client.userId, 1], [
          outsider.userId,
          0,
        ]] as const
      ) {
        const rows = await asUser(
          db,
          viewer,
          (tx) =>
            tx`select full_name,location from public.profiles where id=${freelancer.userId}`,
        );
        assert.equal(rows.length, count);
        if (count) {
          assert.equal(rows[0].location, null);
        }
      }
    },
  );
  await t.step(
    "exclusão: JWT antigo não recria perfil, arquivo nem dados via RPC",
    async () => {
      await reset(db);
      const { userId } = await customer(db);
      await object(db, userId);
      await begin(db, userId);
      const rows = await asUser(
        db,
        userId,
        (tx) =>
          tx`update public.profiles set location='recriada' where id=${userId} returning id`,
      );
      assert.equal(rows.length, 0);
      await assert.rejects(
        () =>
          asUser(
            db,
            userId,
            (tx) =>
              tx`insert into storage.objects(id,bucket_id,name,owner) values(gen_random_uuid(),'resumes',${
                userId + "/new.pdf"
              },${userId})`,
          ),
        /ACCOUNT_DELETED|row-level security/,
      );
      await assert.rejects(
        () =>
          asUser(
            db,
            userId,
            (tx) => tx`select public.switch_role('freelancer')`,
          ),
        /ACCOUNT_DELETED/,
      );
      const other = await customer(db);
      const files = await asUser(
        db,
        other.userId,
        (tx) => tx`select name from storage.objects where bucket_id='resumes'`,
      );
      assert.equal(files.length, 0);
    },
  );
  await t.step(
    "exclusão: conta ativa mantém edição e upload normais",
    async () => {
      await reset(db);
      const { userId } = await customer(db);
      const rows = await asUser(
        db,
        userId,
        (tx) =>
          tx`update public.profiles set location='Cidade válida' where id=${userId} returning id`,
      );
      assert.equal(rows.length, 1);
      await asUser(
        db,
        userId,
        (tx) =>
          tx`insert into storage.objects(id,bucket_id,name,owner) values(gen_random_uuid(),'resumes',${
            userId + "/new.pdf"
          },${userId})`,
      );
    },
  );
  await t.step(
    "exclusão: novos contratos não incluem participante em exclusão",
    async () => {
      await reset(db);
      const { freelancer, contractId } = await contract(db);
      await begin(db, freelancer.userId);
      await assert.rejects(
        () =>
          db`update public.contracts set status='active' where id=${contractId}`,
        /DELETED_CONTRACT_PARTICIPANT/,
      );
    },
  );
  await t.step(
    "exclusão: RPCs privilegiados e helpers não aceitam usuário comum",
    async () => {
      await reset(db);
      const { userId } = await customer(db);
      await assert.rejects(
        () =>
          asUser(
            db,
            userId,
            (tx) => tx`select public.begin_account_deletion(${userId})`,
          ),
        /permission denied/,
      );
      await assert.rejects(
        () =>
          asUser(
            db,
            userId,
            (tx) => tx`select account_private.redact_profile(${userId})`,
          ),
        /permission denied/,
      );
    },
  );
}
