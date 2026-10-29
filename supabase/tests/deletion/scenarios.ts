import assert from "node:assert/strict";
import {
  customer,
  type Database,
  reset,
  sqlFile,
} from "../webhook/fixtures.ts";
import {
  begin,
  contract,
  deletionMigrations,
  dependencies,
  installDeletion,
  object,
  personalProfile,
} from "./fixtures.ts";
import { accessTests } from "./access.ts";
import { recoveryTests } from "./recovery.ts";
import { concurrencyTests } from "./concurrency.ts";

export async function deletionTests(t: Deno.TestContext, db: Database) {
  await reset(db);
  await installDeletion(db);
  await t.step(
    "exclusão: migrations e rollbacks limpos são reaplicáveis",
    async () => {
      for (const name of [...deletionMigrations].reverse()) {
        await sqlFile(
          db,
          `rollbacks/${name}_down.sql`,
        );
      }
      for (const name of deletionMigrations) {
        await sqlFile(
          db,
          `migrations/${name}.sql`,
        );
      }
    },
  );
  await t.step(
    "exclusão definitiva remove currículo, arquivos aninhados e perfil",
    async () => {
      await reset(db);
      const { userId } = await customer(db);
      await personalProfile(db, userId);
      const other = await customer(db);
      await object(db, other.userId);
      for (
        const bucket of [
          "resumes",
          "avatars",
          "portfolio",
          "job_attachments",
          "job_covers",
          "chat_attachments",
        ]
      ) await object(db, userId, bucket, `${userId}/folder/${bucket}.bin`);
      const flow = dependencies(db, userId);
      await flow.run();
      assert.deepEqual(flow.erased, [false]);
      const [r] =
        await db`select (select count(*)::int from auth.users where id=${userId}) users,
      (select count(*)::int from public.profiles where id=${userId}) profiles,
      (select count(*)::int from storage.objects where name like ${
          userId + "/%"
        }) files,
      (select count(*)::int from storage.objects where name like ${
          other.userId + "/%"
        }) other_files`;
      assert.deepEqual(r, { users: 0, profiles: 0, files: 0, other_files: 1 });
      await flow.run();
      assert.deepEqual(flow.erased, [false]);
    },
  );
  await t.step(
    "anonimização limpa todos os campos e mantém contratos e anexos necessários",
    async () => {
      await reset(db);
      const { client, freelancer, contractId } = await contract(db);
      await personalProfile(db, freelancer.userId);
      await object(db, freelancer.userId);
      await object(db, freelancer.userId, "avatars");
      await object(db, freelancer.userId, "portfolio");
      await object(
        db,
        freelancer.userId,
        "chat_attachments",
        `${freelancer.userId}/deliverables/test.pdf`,
      );
      const flow = dependencies(db, freelancer.userId);
      await flow.run();
      assert.deepEqual(flow.erased, [true]);
      const [p] =
        await db`select * from public.profiles where id=${freelancer.userId}`;
      assert.equal(p.full_name, "Usuário removido");
      assert.ok(p.deleted_at);
      assert.equal(p.plan, "free");
      for (
        const key of [
          "headline",
          "location",
          "website_url",
          "linkedin_url",
          "github_url",
          "resume_url",
          "avatar_url",
          "company_name",
          "bio",
          "plan_expires_at",
        ]
      ) assert.equal(p[key], null, key);
      assert.equal(Number(p.hourly_rate), 0);
      assert.deepEqual(p.skills, []);
      assert.equal(p.is_verified, false);
      const [c] =
        await db`select count(*)::int n from public.contracts where id=${contractId}`;
      assert.equal(c.n, 1);
      const files =
        await db`select bucket_id,owner,owner_id from storage.objects where name like ${
          freelancer.userId + "/%"
        }`;
      assert.deepEqual([...files], [{
        bucket_id: "chat_attachments",
        owner: null,
        owner_id: null,
      }]);
      const [r] =
        await db`select phase from public.account_deletion_requests where user_id=${freelancer.userId}`;
      assert.equal(r.phase, "completed");
      const [live] =
        await db`select deleted_at from public.profiles where id=${client.userId}`;
      assert.equal(live.deleted_at, null);
      await flow.run();
      assert.equal(flow.erased.length, 1);
    },
  );
  await t.step(
    "contrato ativo bloqueia a exclusão antes de anonimizar ou remover arquivos",
    async () => {
      await reset(db);
      const { freelancer } = await contract(db, "active");
      await personalProfile(db, freelancer.userId);
      await object(db, freelancer.userId);
      await assert.rejects(
        () => begin(db, freelancer.userId),
        /ACTIVE_CONTRACTS/,
      );
      const [r] =
        await db`select deleted_at,location from public.profiles where id=${freelancer.userId}`;
      assert.equal(r.deleted_at, null);
      assert.equal(r.location, "Cidade privada");
    },
  );
  await t.step(
    "manifesto por lotes não pula objetos e também encontra uploads sem owner",
    async () => {
      await reset(db);
      const { userId } = await customer(db);
      await db`insert into storage.objects(id,bucket_id,name,owner_id)
      select gen_random_uuid(),'resumes',${userId}||'/folder/'||i||'.pdf',null from generate_series(1,205)i`;
      const flow = dependencies(db, userId);
      await flow.run();
      assert.equal(flow.calls.filter((x) => x === "remove").length, 3);
    },
  );
  await recoveryTests(t, db);
  await accessTests(t, db);
  await concurrencyTests(t, db);
}
