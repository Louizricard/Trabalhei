import assert from "node:assert/strict";
import {
  asUser,
  customer,
  type Database,
  reset,
  sqlFile,
} from "../webhook/fixtures.ts";

export const categoriesMigration = "20261113185511_generalist_categories";

async function legacyJob(db: Database, category: string) {
  const { userId } = await customer(db);
  const [job] = await db`insert into public.jobs
    (client_id,title,category,description,budget_min,budget_max)
    values (${userId},'Vaga antiga',${category},'Descrição de uma vaga antiga',10,20)
    returning id`;
  return job.id as string;
}

async function categoryOf(db: Database, id: string) {
  const [row] =
    await db`select category, subcategory from public.jobs where id=${id}`;
  return { category: row.category, subcategory: row.subcategory };
}

export async function categoryTests(t: Deno.TestContext, db: Database) {
  await t.step("categorias: remapeia vagas e alertas sem perder a especialização", async () => {
    await sqlFile(db, `rollbacks/${categoriesMigration}_down.sql`).catch(() => {});
    await reset(db);
    const mobile = await legacyJob(db, "Mobile");
    const devops = await legacyJob(db, "devops");
    const design = await legacyJob(db, "Design");
    const odd = await legacyJob(db, "Testes");
    const { userId } = await customer(db);
    await db`insert into public.job_alerts (user_id,name,category)
      values (${userId},'Alerta antigo','Backend')`;
    await sqlFile(db, `migrations/${categoriesMigration}.sql`);
    assert.deepEqual(await categoryOf(db, mobile), { category: "Tecnologia", subcategory: "Mobile" });
    assert.deepEqual(await categoryOf(db, devops), { category: "Tecnologia", subcategory: "DevOps" });
    assert.deepEqual(await categoryOf(db, design), { category: "Design", subcategory: null });
    assert.deepEqual(await categoryOf(db, odd), { category: "Outros", subcategory: "Testes" });
    const [alert] = await db`select category, subcategory from public.job_alerts
      where user_id=${userId}`;
    assert.deepEqual({ ...alert }, { category: "Tecnologia", subcategory: "Backend" });
  });

  await t.step("categorias: rollback restaura os valores antigos e recusa perder dados", async () => {
    await sqlFile(db, `rollbacks/${categoriesMigration}_down.sql`);
    const rows = await db`select category from public.jobs order by category`;
    assert.ok(rows.some((r) => r.category === "Mobile"));
    assert.ok(rows.some((r) => r.category === "Testes"));
    await sqlFile(db, `migrations/${categoriesMigration}.sql`);
    const { userId } = await customer(db);
    await db`update public.profiles set category='Design', subcategory='UI/UX' where id=${userId}`;
    await assert.rejects(
      sqlFile(db, `rollbacks/${categoriesMigration}_down.sql`),
      /CATEGORY_DATA_PRESENT/,
    );
    await db`update public.profiles set category=null, subcategory=null where id=${userId}`;
  });

  await t.step("categorias: banco recusa área ou subcategoria fora do catálogo", async () => {
    await reset(db);
    const { userId, jobId } = await customer(db);
    const update = (category: string, sub: string | null) =>
      asUser(db, userId, (tx) =>
        tx`update public.jobs set category=${category}, subcategory=${sub} where id=${jobId}`);
    await update("Design", "UI/UX");
    await update("Outros", "Confeitaria");
    await assert.rejects(update("Mobile", null), /jobs_category_area/);
    await assert.rejects(update("Design", "Backend"), /jobs_subcategory_valid/);
  });

  await t.step("categorias: alerta por área ou por subcategoria", async () => {
    await reset(db);
    const freela = await customer(db);
    await db`insert into public.job_alerts (user_id,name,category) values
      (${freela.userId},'Toda tecnologia','Tecnologia')`;
    await db`insert into public.job_alerts (user_id,name,category,subcategory) values
      (${freela.userId},'Só mobile','Tecnologia','Mobile')`;
    const client = await customer(db);
    await asUser(db, client.userId, (tx) =>
      tx`insert into public.jobs (client_id,title,category,subcategory,description,budget_min,budget_max)
        values (${client.userId},'App de delivery','Tecnologia','Backend','API para app de delivery',10,20)`);
    const notes = await db`select a.name from public.notifications n
      join public.job_alerts a on a.id=(n.data->>'alert_id')::uuid
      where n.user_id=${freela.userId} and n.title like '%App de delivery%'
         or (n.user_id=${freela.userId} and n.body='App de delivery')`;
    assert.deepEqual(notes.map((n) => n.name), ["Toda tecnologia"]);
  });
}
