import assert from "node:assert/strict";
import { customer, type Database, reset } from "../webhook/fixtures.ts";
import { begin } from "./fixtures.ts";

export async function concurrencyTests(t: Deno.TestContext, db: Database) {
  await t.step(
    "exclusão: upload iniciado antes termina antes de fechar o perfil",
    async () => {
      await reset(db);
      const { userId } = await customer(db);
      let uploaded!: () => void, release!: () => void;
      const ready = new Promise<void>((r) => uploaded = r),
        gate = new Promise<void>((r) => release = r);
      const upload = db.begin(async (tx) => {
        await tx`set local role authenticated`;
        await tx`select set_config('request.jwt.claim.sub',${userId},true)`;
        await tx`insert into storage.objects(id,bucket_id,name,owner) values(gen_random_uuid(),'resumes',${
          userId + "/inflight.pdf"
        },${userId})`;
        uploaded();
        await gate;
      });
      await ready;
      let closed = false;
      const deletion = begin(db, userId).then((r) => {
        closed = true;
        return r;
      });
      try {
        await db`select pg_sleep(0.1)`;
        assert.equal(closed, false);
      } finally {
        release();
      }
      await upload;
      const r = await deletion;
      const rows =
        await db`select * from public.account_deletion_objects(${userId},${r.token})`;
      assert.equal(rows.length, 1);
      assert.equal(rows[0].name, userId + "/inflight.pdf");
    },
  );
  await t.step(
    "exclusão: checkout ativo ou POST financeiro inconclusivo exige conciliação",
    async () => {
      await reset(db);
      const { userId } = await customer(db);
      const [r] =
        await db`select public.claim_billing_checkout(${userId},'pro_monthly',null,'PIX','') r`;
      await assert.rejects(() => begin(db, userId), /DELETION_BILLING_PENDING/);
      await db`select public.reserve_billing_step(${r.r.checkout.id},${r.r.token},${
        r.r.checkout.id + ":subscription"
      })`;
      await db`select public.release_billing_checkout(${r.r.checkout.id},${r.r.token})`;
      await assert.rejects(() => begin(db, userId), /DELETION_BILLING_PENDING/);
      const [p] =
        await db`select deleted_at from public.profiles where id=${userId}`;
      assert.equal(p.deleted_at, null);
    },
  );
  await t.step(
    "exclusão: chamada de checkout já autenticada não reserva depois do fechamento",
    async () => {
      await reset(db);
      const { userId } = await customer(db);
      await begin(db, userId);
      await assert.rejects(
        () =>
          db`select public.claim_billing_checkout(${userId},'pro_monthly',null,'PIX','')`,
        /ACCOUNT_DELETED/,
      );
    },
  );
}
