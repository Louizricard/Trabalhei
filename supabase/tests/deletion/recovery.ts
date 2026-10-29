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
  object,
} from "./fixtures.ts";

export async function recoveryTests(t: Deno.TestContext, db: Database) {
  for (
    const fault of ["billing", "list", "remove", "data", "auth", "complete"]
  ) {
    await t.step(
      `exclusão: falha em ${fault} fica pendente e permite retomada`,
      async () => {
        await reset(db);
        const { freelancer } = await contract(db);
        await object(db, freelancer.userId);
        const flow = dependencies(db, freelancer.userId);
        flow.faults.add(fault);
        await assert.rejects(flow.run, /exclusão não foi concluída/);
        const [r] =
          await db`select phase,last_error_code,lease_token from public.account_deletion_requests where user_id=${freelancer.userId}`;
        assert.notEqual(r.phase, "completed");
        assert.equal(r.lease_token, null);
        assert.equal(
          r.last_error_code,
          ({ list: "storage", remove: "storage" } as Record<string, string>)[
            fault
          ] ?? fault,
        );
        if (["billing", "list", "remove", "data"].includes(fault)) {
          assert
            .equal(flow.erased.length, 0);
        }
        await flow.run();
        const [done] =
          await db`select phase from public.account_deletion_requests where user_id=${freelancer.userId}`;
        assert.equal(done.phase, "completed");
      },
    );
  }
  await t.step(
    "exclusão: lease impede concorrência e token vencido não libera novo pedido",
    async () => {
      await reset(db);
      const { userId } = await customer(db);
      const first = await begin(db, userId);
      await assert.rejects(() => begin(db, userId), /DELETION_BUSY/);
      await db`update public.account_deletion_requests set lease_until=now()-interval '1 second' where user_id=${userId}`;
      const next = await begin(db, userId);
      assert.notEqual(first.token, next.token);
      await assert.rejects(
        () =>
          db`select * from public.account_deletion_objects(${userId},${first.token})`,
        /DELETION_LEASE_LOST/,
      );
      await db`select public.fail_account_deletion(${userId},${first.token},'storage')`;
      await assert.rejects(() => begin(db, userId), /DELETION_BUSY/);
    },
  );
  await t.step(
    "exclusão: não avança para Auth enquanto existir currículo",
    async () => {
      await reset(db);
      const { userId } = await customer(db);
      await object(db, userId);
      const r = await begin(db, userId);
      await assert.rejects(
        () =>
          db`select public.prepare_account_auth_deletion(${userId},${r.token})`,
        /STORAGE_NOT_EMPTY/,
      );
      await assert.rejects(
        () => db`select public.complete_account_deletion(${userId},${r.token})`,
        /DELETION_NOT_READY/,
      );
    },
  );
  await t.step(
    "exclusão: rollback recusa reabrir acesso após pedido real",
    async () => {
      await reset(db);
      const { userId } = await customer(db);
      await begin(db, userId);
      for (const name of [...deletionMigrations].reverse()) {
        await assert.rejects(
          () => sqlFile(db, `rollbacks/${name}_down.sql`),
          /ACCOUNT_DELETION_DATA_PRESENT/,
        );
      }
    },
  );
}
