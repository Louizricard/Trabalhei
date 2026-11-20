import assert from "node:assert/strict";
import {
  asUser,
  customer,
  type Database,
  reset,
  sqlFile,
} from "../webhook/fixtures.ts";

export const playMigration = "20261120172358_play_billing";

const days = (n: number) => new Date(Date.now() + n * 86_400_000).toISOString();

async function plan(db: Database, user: string) {
  const [p] =
    await db`select plan, plan_expires_at from public.profiles where id=${user}`;
  return p as { plan: string; plan_expires_at: Date | null };
}

async function sub(
  db: Database,
  user: string,
  token: string,
  state: string,
  expires: string | null,
) {
  const [r] =
    await db`select public.apply_play_subscription(${user},${token},'GPA.1',${state},${expires}) r`;
  return r.r as Record<string, unknown>;
}

async function featured(db: Database, job: string) {
  const [j] = await db`select featured_until from public.jobs where id=${job}`;
  return j.featured_until as Date | null;
}

export async function playTests(t: Deno.TestContext, db: Database) {
  await sqlFile(db, `migrations/${playMigration}.sql`);

  await t.step(
    "play: rollback e reaplicação limpos; rollback recusa com compras",
    async () => {
      await reset(db);
      await sqlFile(db, `rollbacks/${playMigration}_down.sql`);
      const [gone] =
        await db`select to_regclass('public.play_purchases') is null as gone`;
      assert.equal(gone.gone, true);
      await sqlFile(db, `migrations/${playMigration}.sql`);
      const { userId } = await customer(db);
      await sub(db, userId, "tok-rb", "active", days(30));
      await assert.rejects(
        sqlFile(db, `rollbacks/${playMigration}_down.sql`),
        /PLAY_PURCHASES_PRESENT/,
      );
    },
  );

  await t.step(
    "play: assinatura ativa concede Pro; cancelada vale até o fim; expirada tira",
    async () => {
      await reset(db);
      const { userId } = await customer(db);
      await sub(db, userId, "tok-1", "active", days(30));
      assert.equal((await plan(db, userId)).plan, "pro");
      await sub(db, userId, "tok-1", "cancelled", days(10));
      const p = await plan(db, userId);
      assert.equal(p.plan, "pro");
      assert.ok(
        Math.abs(p.plan_expires_at!.getTime() - Date.parse(days(10))) < 5_000,
      );
      await sub(db, userId, "tok-1", "expired", null);
      assert.equal((await plan(db, userId)).plan, "free");
      const [n] = await db`select count(*)::int n from public.notifications
      where user_id=${userId} and title='Plano Pro ativo'`;
      assert.equal(n.n, 1, "aviso só na ativação, não a cada reconferência");
    },
  );

  await t.step(
    "play: pendente não concede; token de outro usuário é recusado",
    async () => {
      await reset(db);
      const a = (await customer(db)).userId, b = (await customer(db)).userId;
      await sub(db, a, "tok-2", "pending", null);
      assert.equal((await plan(db, a)).plan, "free");
      await assert.rejects(
        sub(db, b, "tok-2", "active", days(30)),
        /PURCHASE_OWNED_BY_OTHER/,
      );
      assert.equal((await plan(db, b)).plan, "free");
    },
  );

  await t.step(
    "play: estorno da assinatura tira o Pro e não volta com reconferência",
    async () => {
      await reset(db);
      const { userId } = await customer(db);
      await sub(db, userId, "tok-3", "active", days(30));
      await db`select public.revoke_play_purchase('tok-3')`;
      assert.equal((await plan(db, userId)).plan, "free");
      const r = await sub(db, userId, "tok-3", "active", days(30));
      assert.equal(r.state, "refunded");
      assert.equal((await plan(db, userId)).plan, "free");
    },
  );

  await t.step(
    "play: Pro do Google soma com cupom/concessão sem encurtar",
    async () => {
      await reset(db);
      const { userId } = await customer(db);
      await db`select public.grant_pro(${userId},60,'Teste.')`;
      await sub(db, userId, "tok-4", "active", days(30));
      await sub(db, userId, "tok-4", "expired", null);
      const p = await plan(db, userId);
      assert.equal(p.plan, "pro");
      assert.ok(p.plan_expires_at!.getTime() > Date.parse(days(59)));
    },
  );

  await t.step(
    "play: destaque aplica uma vez, estende e o estorno remove o período",
    async () => {
      await reset(db);
      const { userId, jobId } = await customer(db);
      const [first] =
        await db`select public.apply_play_feature(${userId},'tok-f1','GPA.2',${jobId}) r`;
      assert.equal(first.r.state, "applied");
      const once = await featured(db, jobId);
      assert.ok(once!.getTime() > Date.parse(days(6.9)));
      await db`select public.apply_play_feature(${userId},'tok-f1','GPA.2',${jobId})`;
      assert.equal(
        (await featured(db, jobId))!.getTime(),
        once!.getTime(),
        "reenvio não duplica",
      );
      await db`select public.apply_play_feature(${userId},'tok-f2','GPA.3',${jobId})`;
      assert.ok(
        (await featured(db, jobId))!.getTime() > Date.parse(days(13.9)),
      );
      await db`select public.revoke_play_purchase('tok-f2')`;
      const after = await featured(db, jobId);
      assert.ok(Math.abs(after!.getTime() - once!.getTime()) < 5_000);
    },
  );

  await t.step("play: destaque recusa vaga alheia", async () => {
    await reset(db);
    const owner = await customer(db), other = await customer(db);
    await assert.rejects(
      db`select public.apply_play_feature(${other.userId},'tok-f3','GPA.4',${owner.jobId})`,
      /JOB_NOT_FOUND/,
    );
  });

  await t.step(
    "play: funções só para service_role; usuário lê só as próprias compras",
    async () => {
      await reset(db);
      const a = (await customer(db)).userId, b = (await customer(db)).userId;
      await sub(db, a, "tok-5", "active", days(30));
      await assert.rejects(
        asUser(
          db,
          b,
          (tx) =>
            tx`select public.apply_play_subscription(${b},'x','y','active',now())`,
        ),
        /permission denied/,
      );
      await assert.rejects(
        asUser(db, b, (tx) => tx`select public.revoke_play_purchase('tok-5')`),
        /permission denied/,
      );
      const mine = await asUser(
        db,
        a,
        (tx) => tx`select purchase_token from public.play_purchases`,
      );
      const theirs = await asUser(
        db,
        b,
        (tx) => tx`select purchase_token from public.play_purchases`,
      );
      assert.equal(mine.length, 1);
      assert.equal(theirs.length, 0);
      await assert.rejects(
        asUser(
          db,
          a,
          (tx) => tx`update public.play_purchases set state='active'`,
        ),
        /permission denied/,
      );
    },
  );
}
