import postgres from "postgres";
import assert from "node:assert/strict";

export const receiptsMigration = "20261029150428_asaas_webhook_receipts";
export const processingMigration = "20261029150430_asaas_webhook_processing";

export function testDatabase() {
  const url = Deno.env.get("TEST_DATABASE_URL");
  if (!url) {
    throw new Error(
      "Defina TEST_DATABASE_URL para um PostgreSQL local descartável.",
    );
  }
  const parsed = new URL(url);
  if (
    !["localhost", "127.0.0.1", "[::1]"].includes(parsed.hostname) ||
    !parsed.pathname.endsWith("_test")
  ) {
    throw new Error(
      "Os testes só podem usar localhost e banco com sufixo _test.",
    );
  }
  return postgres(url, { max: 12, onnotice: () => {} });
}

export type Database = ReturnType<typeof testDatabase>;
const base = new URL("../../", import.meta.url);
export async function sqlFile(db: Database, path: string) {
  await db.unsafe(await Deno.readTextFile(new URL(path, base)));
}

export async function install(db: Database) {
  await sqlFile(db, "tests/webhook/bootstrap.sql");
  await sqlFile(db, "migrations/20261015211818_initial_schema.sql");
  await sqlFile(db, "migrations/20261026162219_plans_and_limits.sql");
  await sqlFile(db, "migrations/20261026162253_coupons.sql");
  await upgrade(db);
}

export async function upgrade(db: Database) {
  await sqlFile(db, `migrations/${receiptsMigration}.sql`);
  await sqlFile(db, `migrations/${processingMigration}.sql`);
}

export async function reset(db: Database) {
  await db`truncate auth.users, public.billing_events, public.billing_payment_receipts cascade`;
}

export async function customer(db: Database) {
  const id = crypto.randomUUID();
  await db`insert into auth.users (id, email, raw_user_meta_data)
    values (${id}, ${`${id}@example.invalid`}, '{"full_name":"Teste Webhook","role":"client"}')`;
  const [job] = await db`insert into public.jobs
    (client_id,title,category,description,budget_min,budget_max)
    values (${id},'Vaga de teste','Testes','Descrição para testar cobranças',10,20) returning id`;
  return { userId: id, jobId: job.id as string };
}

export async function feature(
  db: Database,
  jobId: string,
  userId: string,
  paymentId = crypto.randomUUID(),
) {
  const [row] = await db`insert into public.job_featurings
    (job_id,user_id,asaas_payment_id,days,amount) values (${jobId},${userId},${paymentId},7,9.9) returning id`;
  return { featuringId: row.id as string, paymentId };
}

export async function subscription(
  db: Database,
  userId: string,
  providerId = crypto.randomUUID(),
) {
  await db`insert into public.subscriptions (user_id,asaas_subscription_id,billing_type)
    values (${userId},${providerId},'PIX')`;
  return providerId;
}

export function paymentEvent(
  paymentId: string,
  subId?: string,
  event = "PAYMENT_RECEIVED",
) {
  return {
    id: crypto.randomUUID(),
    event,
    payment: {
      id: paymentId,
      ...(subId
        ? { subscription: subId }
        : { externalReference: `feature:${paymentId}` }),
    },
  };
}

export async function receive(db: Database, payload: unknown) {
  const [row] = await db`select public.receive_asaas_billing_event(${
    db.json(payload as never)
  }::jsonb) result`;
  return row.result;
}

export async function assertFeature(
  db: Database,
  jobId: string,
  days: number,
  payments = 1,
) {
  const [row] =
    await db`select extract(epoch from (featured_until-now()))/86400 remaining
    from public.jobs where id=${jobId}`;
  assert.ok(
    Number(row.remaining) > days - 0.01 && Number(row.remaining) <= days,
  );
  const [counts] =
    await db`select (select count(*) from public.billing_payment_receipts)::int receipts,
    (select count(*) from public.notifications)::int notifications`;
  assert.equal(counts.receipts, payments);
  assert.equal(counts.notifications, payments);
}
