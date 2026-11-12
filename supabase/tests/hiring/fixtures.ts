import { asUser, customer, type Database } from "../webhook/fixtures.ts";

export const hiringMigration = "20261112120000_hiring_journey_fixes";
export const coverLetter =
  "Carta de apresentação de teste com mais de cinquenta caracteres para a vaga.";

export type Milestone = { title: string; amount: unknown; days: unknown };

export async function freelancer(db: Database) {
  const { userId } = await customer(db);
  await db`update public.profiles set role='freelancer' where id=${userId}`;
  return userId;
}

export async function propose(
  db: Database,
  user: string,
  jobId: string,
  bid = 100,
  milestones: unknown = [],
) {
  return await asUser(db, user, async (tx) => {
    const [r] =
      await tx`select (public.submit_proposal(${jobId},${bid},7,${coverLetter},${
        tx.json(milestones as never)
      })).id`;
    return r.id as string;
  });
}

export async function proposal(
  db: Database,
  bid = 100,
  milestones: unknown = [],
) {
  const client = await customer(db), worker = await freelancer(db);
  const proposalId = await propose(db, worker, client.jobId, bid, milestones);
  return { client: client.userId, jobId: client.jobId, worker, proposalId };
}

export async function accept(
  db: Database,
  client: string,
  proposalId: string,
  expected: number | null = null,
) {
  return await asUser(db, client, async (tx) => {
    const [r] = expected === null
      ? await tx`select public.accept_proposal(${proposalId}) r`
      : await tx`select public.accept_proposal(${proposalId},${expected}::numeric) r`;
    return r.r as { contract_id: string; conversation_id: string };
  });
}

export async function counter(
  db: Database,
  client: string,
  proposalId: string,
  price: number,
) {
  await asUser(
    db,
    client,
    (tx) => tx`select public.make_counter_offer(${proposalId},${price},5,null)`,
  );
}

export async function hired(db: Database, milestones: unknown = []) {
  const p = await proposal(db, 100, milestones);
  const { contract_id } = await accept(db, p.client, p.proposalId);
  const rows =
    await db`select id from public.milestones where contract_id=${contract_id} order by sort_order`;
  return {
    ...p,
    contractId: contract_id,
    milestones: rows.map((r) => r.id as string),
  };
}

export async function deliver(
  db: Database,
  worker: string,
  milestoneId: string,
) {
  await asUser(
    db,
    worker,
    (tx) =>
      tx`select public.submit_deliverable(${milestoneId},'Entrega de teste','[]'::jsonb)`,
  );
}

export function approve(db: Database, client: string, milestoneId: string) {
  return asUser(
    db,
    client,
    (tx) => tx`select public.approve_milestone(${milestoneId})`,
  );
}

// Mantém a transação aberta (com seus locks) até release(), para forçar corridas reais.
export function held<T>(
  db: Database,
  user: string,
  run: (tx: Database) => Promise<T>,
) {
  let release!: () => void, ready!: () => void;
  const gate = new Promise<void>((r) => release = r);
  const started = new Promise<void>((r) => ready = r);
  const done = db.begin(async (tx) => {
    await tx`set local role authenticated`;
    await tx`select set_config('request.jwt.claim.sub',${user},true)`;
    const result = await run(tx as unknown as Database);
    ready();
    await gate;
    return result;
  });
  done.catch(() => ready());
  return { started, release, done };
}

export async function settle<T>(p: Promise<T>) {
  try {
    return { ok: true as const, value: await p };
  } catch (error) {
    return { ok: false as const, error: String(error) };
  }
}
