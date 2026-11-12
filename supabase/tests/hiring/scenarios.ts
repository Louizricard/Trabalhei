import assert from "node:assert/strict";
import {
  asUser,
  customer,
  type Database,
  reset,
  sqlFile,
} from "../webhook/fixtures.ts";
import {
  accept,
  approve,
  counter,
  deliver,
  freelancer,
  held,
  hired,
  hiringMigration,
  proposal,
  propose,
  settle,
} from "./fixtures.ts";

const pause = (db: Database) => db`select pg_sleep(0.2)`;

async function status(db: Database, table: string, id: string) {
  const [r] = await db.unsafe(
    `select status from public.${table} where id=$1`,
    [id],
  );
  return r.status as string;
}

function cancel(
  db: Database,
  user: string,
  contractId: string,
  reason: string,
) {
  return asUser(
    db,
    user,
    (tx) => tx`select public.cancel_contract(${contractId},${reason})`,
  );
}

export async function hiringTests(t: Deno.TestContext, db: Database) {
  await sqlFile(db, `migrations/${hiringMigration}.sql`);

  await t.step("contratação: rollback e reaplicação limpos", async () => {
    await sqlFile(db, `rollbacks/${hiringMigration}_down.sql`);
    const [old] = await db`select
      to_regprocedure('public.accept_proposal(uuid)') is not null as legacy,
      to_regprocedure('public.cancel_contract(uuid,text)') is null as gone`;
    assert.deepEqual({ ...old }, { legacy: true, gone: true });
    await sqlFile(db, `migrations/${hiringMigration}.sql`);
    const [now] = await db`select
      to_regprocedure('public.accept_proposal(uuid)') is null as replaced,
      to_regprocedure('public.cancel_contract(uuid,text)') is not null as created`;
    assert.deepEqual({ ...now }, { replaced: true, created: true });
  });

  for (const linked of [true, false]) {
    await t.step(
      `B1: aprovações simultâneas dos últimos marcos concluem o contrato (conversa ${
        linked ? "vinculada" : "ausente"
      })`,
      async () => {
        await reset(db);
        const ms = [
          { title: "Parte 1", amount: 50, days: 3 },
          { title: "Parte 2", amount: 50, days: 6 },
        ];
        const h = await hired(db, ms);
        assert.equal(h.milestones.length, 2);
        // Sem conversa, nada além do lock do contrato serializa as aprovações.
        if (
          !linked
        ) {
          await db`update public.conversations set contract_id=null where contract_id=${h.contractId}`;
        }
        for (const m of h.milestones) {
          await deliver(db, h.worker, m);
        }
        const first = held(
          db,
          h.client,
          (tx) => tx`select public.approve_milestone(${h.milestones[0]})`,
        );
        await first.started;
        const second = settle(approve(db, h.client, h.milestones[1]));
        await pause(db);
        first.release();
        await first.done;
        assert.equal((await second).ok, true);
        assert.equal(await status(db, "contracts", h.contractId), "completed");
        assert.equal(await status(db, "jobs", h.jobId), "completed");
        const [p] =
          await db`select completed_jobs_count n from public.profiles where id=${h.worker}`;
        assert.equal(p.n, 1);
        const [n] = await db`select count(*)::int n from public.notifications
        where user_id=${h.worker} and data->>'contract_id'=${h.contractId} and title='Projeto concluído'`;
        assert.equal(n.n, 1, "freelancer é convidado a avaliar");
      },
    );
  }

  await t.step(
    "B2: qualquer parte encerra contrato ativo com motivo",
    async () => {
      await reset(db);
      const h = await hired(db);
      const outsider = await freelancer(db);
      await assert.rejects(
        cancel(db, outsider, h.contractId, "Motivo qualquer de teste"),
        /CONTRACT_NOT_FOUND/,
      );
      await assert.rejects(
        cancel(db, h.client, h.contractId, "curto"),
        /CANCEL_REASON_REQUIRED/,
      );
      await deliver(db, h.worker, h.milestones[0]);
      await cancel(
        db,
        h.worker,
        h.contractId,
        "Não consigo mais atender o prazo combinado.",
      );
      const [c] =
        await db`select status,cancelled_by,cancel_reason,cancelled_at is not null as dated
      from public.contracts where id=${h.contractId}`;
      assert.deepEqual({ ...c }, {
        status: "cancelled",
        cancelled_by: h.worker,
        cancel_reason: "Não consigo mais atender o prazo combinado.",
        dated: true,
      });
      assert.equal(await status(db, "jobs", h.jobId), "cancelled");
      const [n] = await db`select count(*)::int n from public.notifications
      where user_id=${h.client} and data->>'contract_id'=${h.contractId} and title='Contrato encerrado'`;
      assert.equal(n.n, 1);
      const [m] = await db`select count(*)::int n from public.messages ms
      join public.conversations cv on cv.id=ms.conversation_id
      where cv.contract_id=${h.contractId} and ms.message_type='system_event' and ms.content like '%encerrado%'`;
      assert.equal(m.n, 1);
      await assert.rejects(
        approve(db, h.client, h.milestones[0]),
        /CONTRACT_NOT_ACTIVE/,
      );
      await assert.rejects(
        cancel(db, h.client, h.contractId, "Tentando de novo encerrar"),
        /CONTRACT_NOT_ACTIVE/,
      );
      await assert.rejects(
        asUser(
          db,
          h.client,
          (tx) =>
            tx`insert into public.reviews(contract_id,reviewer_id,reviewee_id,rating)
        values(${h.contractId},${h.client},${h.worker},5)`,
        ),
      );
    },
  );

  await t.step("B3: marcos malformados são recusados no envio", async () => {
    await reset(db);
    const { jobId } = await customer(db);
    const worker = await freelancer(db);
    for (
      const bad of [
        { title: "objeto", amount: 100, days: 3 },
        [{ title: "A", amount: "abc", days: 3 }],
        [{ title: "A", amount: -100, days: 3 }, {
          title: "B",
          amount: 200,
          days: 3,
        }],
        [{ title: "A", amount: 100, days: "x" }],
        [{ title: "A", amount: 100, days: 99999 }],
        [{ title: "A", amount: 100, days: -2 }],
        [{ title: " ", amount: 100, days: 3 }],
        [{ title: "A", amount: 60, days: 3 }],
        Array.from(
          { length: 21 },
          (_, i) => ({ title: `M${i}`, amount: 100 / 21, days: 1 }),
        ),
      ]
    ) {
      await assert.rejects(
        propose(db, worker, jobId, 100, bad),
        /INVALID_MILESTONES/,
        JSON.stringify(bad),
      );
    }
    await propose(db, worker, jobId, 100, [
      { title: "A", amount: 40, days: 2 },
      { title: "B", amount: 60, days: 4 },
    ]);
  });

  await t.step(
    "B4: recusa concorrente não sobrescreve proposta aceita",
    async () => {
      await reset(db);
      const p = await proposal(db);
      await counter(db, p.client, p.proposalId, 150);
      const acceptance = held(
        db,
        p.worker,
        (tx) => tx`select public.accept_counter_offer(${p.proposalId})`,
      );
      await acceptance.started;
      const rejection = settle(
        asUser(
          db,
          p.client,
          (tx) => tx`select public.reject_proposal(${p.proposalId})`,
        ),
      );
      const reoffer = settle(
        asUser(
          db,
          p.client,
          (tx) =>
            tx`select public.make_counter_offer(${p.proposalId},120,4,null)`,
        ),
      );
      await pause(db);
      acceptance.release();
      await acceptance.done;
      const [r, o] = await Promise.all([rejection, reoffer]);
      assert.equal(r.ok, false);
      assert.match(r.ok ? "" : r.error, /PROPOSAL_ALREADY_DECIDED/);
      assert.equal(o.ok, false);
      assert.equal(await status(db, "proposals", p.proposalId), "accepted");
    },
  );

  await t.step(
    "B5: cota mensal não é furada por envios paralelos",
    async () => {
      await reset(db);
      await db`update public.platform_settings set free_monthly_proposals=1`;
      try {
        const a = await customer(db), b = await customer(db);
        const worker = await freelancer(db);
        const first = held(
          db,
          worker,
          (tx) =>
            tx`select public.submit_proposal(${a.jobId},100,7,${
              "x".repeat(60)
            },'[]'::jsonb)`,
        );
        await first.started;
        const second = settle(propose(db, worker, b.jobId));
        await pause(db);
        first.release();
        await first.done;
        const r = await second;
        assert.equal(r.ok, false);
        assert.match(r.ok ? "" : r.error, /PROPOSAL_QUOTA_EXCEEDED/);
      } finally {
        await db`update public.platform_settings set free_monthly_proposals=10`;
      }
    },
  );

  await t.step(
    "B6: aceite com valor esperado diferente é recusado",
    async () => {
      await reset(db);
      const p = await proposal(db, 100);
      await propose(db, p.worker, p.jobId, 500);
      await assert.rejects(
        accept(db, p.client, p.proposalId, 100),
        /PROPOSAL_CHANGED/,
      );
      assert.equal(await status(db, "proposals", p.proposalId), "pending");
      const r = await accept(db, p.client, p.proposalId, 500);
      const [c] =
        await db`select total_amount::float8 v from public.contracts where id=${r.contract_id}`;
      assert.equal(c.v, 500);
      const legacy = await proposal(db, 80);
      await asUser(
        db,
        legacy.client,
        (tx) => tx`select public.accept_proposal(${legacy.proposalId})`,
      );
      assert.equal(
        await status(db, "proposals", legacy.proposalId),
        "accepted",
      );
    },
  );

  await t.step(
    "B7: cliente contrata pelo valor original após contraproposta",
    async () => {
      await reset(db);
      const p = await proposal(db, 100);
      await counter(db, p.client, p.proposalId, 80);
      const r = await accept(db, p.client, p.proposalId, 100);
      const [c] =
        await db`select total_amount::float8 v from public.contracts where id=${r.contract_id}`;
      assert.equal(c.v, 100);
      assert.equal(await status(db, "proposals", p.proposalId), "accepted");
      assert.equal(await status(db, "jobs", p.jobId), "in_progress");
      await assert.rejects(
        accept(db, p.client, p.proposalId, 100),
        /PROPOSAL_NOT_PENDING/,
      );
    },
  );

  await t.step("B8: reenvio não apaga contraproposta pendente", async () => {
    await reset(db);
    const p = await proposal(db, 100);
    await counter(db, p.client, p.proposalId, 80);
    await assert.rejects(
      propose(db, p.worker, p.jobId, 90),
      /COUNTER_OFFER_PENDING/,
    );
    const [kept] =
      await db`select status,counter_price::float8 price from public.proposals where id=${p.proposalId}`;
    assert.deepEqual({ ...kept }, { status: "counter_offered", price: 80 });
    await asUser(
      db,
      p.worker,
      (tx) => tx`select public.reject_counter_offer(${p.proposalId})`,
    );
    await propose(db, p.worker, p.jobId, 90);
    assert.equal(await status(db, "proposals", p.proposalId), "pending");
  });

  await t.step(
    "B9: marcos propostos acompanham o valor da contraproposta",
    async () => {
      await reset(db);
      const p = await proposal(db, 100, [
        { title: "A", amount: 33.33, days: 2 },
        { title: "B", amount: 33.33, days: 4 },
        { title: "C", amount: 33.34, days: 6 },
      ]);
      await counter(db, p.client, p.proposalId, 50);
      const r = await asUser(db, p.worker, async (tx) => {
        const [x] =
          await tx`select public.accept_counter_offer(${p.proposalId}) r`;
        return x.r as { contract_id: string };
      });
      const rows = await db`select title,amount::float8 v from public.milestones
      where contract_id=${r.contract_id} order by sort_order`;
      assert.deepEqual(rows.map((x) => x.title), ["A", "B", "C"]);
      assert.deepEqual(rows.map((x) => x.v), [16.67, 16.67, 16.66]);
    },
  );

  await t.step(
    "regressões: contratação dupla, vaga própria e vaga fechada",
    async () => {
      await reset(db);
      const p = await proposal(db);
      const other = await freelancer(db);
      const second = await propose(db, other, p.jobId, 120);
      await accept(db, p.client, p.proposalId);
      await assert.rejects(
        accept(db, p.client, second),
        /PROPOSAL_NOT_PENDING/,
      );
      await assert.rejects(
        propose(db, other, p.jobId, 130),
        /JOB_NOT_OPEN|PROPOSAL_ALREADY_DECIDED/,
      );
      const own = await customer(db);
      await db`update public.profiles set role='freelancer' where id=${own.userId}`;
      await assert.rejects(
        propose(db, own.userId, own.jobId),
        /CANNOT_APPLY_TO_OWN_JOB/,
      );
    },
  );

  await t.step(
    "rollback recusa apagar motivos de contratos encerrados",
    async () => {
      await reset(db);
      const h = await hired(db);
      await cancel(
        db,
        h.client,
        h.contractId,
        "Projeto suspenso pela empresa.",
      );
      await assert.rejects(
        sqlFile(db, `rollbacks/${hiringMigration}_down.sql`),
        /CANCELLED_CONTRACTS_PRESENT/,
      );
      const [c] =
        await db`select cancel_reason from public.contracts where id=${h.contractId}`;
      assert.equal(c.cancel_reason, "Projeto suspenso pela empresa.");
    },
  );
}
