import assert from "node:assert/strict";
import {
  asUser,
  customer,
  type Database,
  reset,
  sqlFile,
} from "../webhook/fixtures.ts";

export const chatSafetyMigration = "20261117130000_chat_safety";

async function pair(db: Database) {
  const client = await customer(db);
  const worker = (await customer(db)).userId;
  await db`update public.profiles set role='freelancer' where id=${worker}`;
  const conv = await asUser(db, client.userId, async (tx) => {
    const [r] =
      await tx`select public.get_or_create_conversation(${client.userId},${worker},${client.jobId}) id`;
    return r.id as string;
  });
  return { client: client.userId, worker, conv, jobId: client.jobId };
}

async function send(db: Database, user: string, conv: string, content = "Olá") {
  return await asUser(db, user, async (tx) => {
    const [m] =
      await tx`insert into public.messages (conversation_id,sender_id,content)
      values (${conv},${user},${content}) returning id`;
    return m.id as string;
  });
}

async function admin(db: Database) {
  const id = (await customer(db)).userId;
  await db`insert into public.admins (user_id) values (${id})`;
  return id;
}

// A suíte de exclusão já criou admins e suspended_at; aqui entra o resto da moderação
// (denúncias e funções de admin), que esta migration altera.
async function installModeration(db: Database) {
  const [has] =
    await db`select to_regclass('public.reports') is not null as ok`;
  if (has.ok) return;
  const sql = await Deno.readTextFile(
    new URL(
      "../../migrations/20261026110842_admin_moderation.sql",
      import.meta.url,
    ),
  );
  // Só is_admin, a tabela de denúncias e require_admin: as funções de admin seguintes já foram
  // redefinidas por migrations posteriores carregadas na instalação.
  const part = (from: string, to: string) =>
    sql.slice(sql.indexOf(from), sql.indexOf(to));
  await db.unsafe(
    part(
      "create function public.is_admin",
      "alter table public.profiles add column suspended_at",
    ) +
      part(
        "create table public.reports",
        "create function public.admin_overview",
      ),
  );
  // No Supabase, authenticated recebe os privilégios padrão das tabelas; quem barra é a RLS.
  await db`grant select, insert on public.reports to authenticated`;
}

export async function chatSafetyTests(t: Deno.TestContext, db: Database) {
  await installModeration(db);
  await sqlFile(db, `migrations/${chatSafetyMigration}.sql`);

  await t.step(
    "chat: rollback e reaplicação limpos; rollback recusa com denúncias de mensagem",
    async () => {
      await reset(db);
      await sqlFile(db, `rollbacks/${chatSafetyMigration}_down.sql`);
      const [gone] =
        await db`select to_regclass('public.user_blocks') is null as gone`;
      assert.equal(gone.gone, true);
      await sqlFile(db, `migrations/${chatSafetyMigration}.sql`);
      const p = await pair(db);
      const msg = await send(db, p.worker, p.conv);
      await asUser(
        db,
        p.client,
        (tx) => tx`select public.report_message(${msg},'spam',null)`,
      );
      await assert.rejects(
        sqlFile(db, `rollbacks/${chatSafetyMigration}_down.sql`),
        /MESSAGE_REPORTS_PRESENT/,
      );
    },
  );

  await t.step(
    "chat: bloqueio impede mensagens nos dois sentidos e conversa nova",
    async () => {
      await reset(db);
      const p = await pair(db);
      await send(db, p.worker, p.conv);
      await asUser(
        db,
        p.client,
        (tx) => tx`select public.block_user(${p.worker})`,
      );
      await assert.rejects(send(db, p.worker, p.conv), /USER_BLOCKED/);
      await assert.rejects(send(db, p.client, p.conv), /USER_BLOCKED/);
      await assert.rejects(
        asUser(
          db,
          p.worker,
          (tx) =>
            tx`select public.get_or_create_conversation(${p.client},${p.worker},null)`,
        ),
        /USER_BLOCKED/,
      );
      // Mensagem de sistema (contrato) continua passando.
      await db`select public._system_message(${p.conv},${p.client},'Evento do contrato')`;
      await asUser(
        db,
        p.client,
        (tx) => tx`select public.unblock_user(${p.worker})`,
      );
      await send(db, p.worker, p.conv, "De volta");
    },
  );

  await t.step("chat: bloqueio é privado e não aceita a si mesmo", async () => {
    await reset(db);
    const p = await pair(db);
    await asUser(
      db,
      p.client,
      (tx) => tx`select public.block_user(${p.worker})`,
    );
    await asUser(
      db,
      p.client,
      (tx) => tx`select public.block_user(${p.worker})`,
    );
    const mine = await asUser(
      db,
      p.client,
      (tx) => tx`select blocked_id from public.user_blocks`,
    );
    const theirs = await asUser(
      db,
      p.worker,
      (tx) => tx`select blocked_id from public.user_blocks`,
    );
    assert.equal(mine.length, 1);
    assert.equal(theirs.length, 0, "quem foi bloqueado não vê quem bloqueou");
    await assert.rejects(
      asUser(db, p.client, (tx) => tx`select public.block_user(${p.client})`),
      /INVALID_BLOCK/,
    );
    await assert.rejects(
      asUser(
        db,
        p.client,
        (tx) =>
          tx`insert into public.user_blocks values (${p.client},${p.worker})`,
      ),
      /permission denied/,
    );
  });

  await t.step(
    "chat: denúncia de mensagem guarda a evidência e só vale para participante",
    async () => {
      await reset(db);
      const p = await pair(db);
      const msg = await send(db, p.worker, p.conv, "Me paga por fora pelo Pix");
      const own = await send(db, p.client, p.conv, "Minha mensagem");
      const first = await asUser(db, p.client, async (tx) => {
        const [r] =
          await tx`select public.report_message(${msg},'off_platform_payment','Pediu pagamento fora') id`;
        return r.id as string;
      });
      const again = await asUser(db, p.client, async (tx) => {
        const [r] =
          await tx`select public.report_message(${msg},'spam',null) id`;
        return r.id as string;
      });
      assert.equal(again, first, "uma denúncia aberta por mensagem");
      const [r] =
        await db`select target_type, conversation_id, evidence from public.reports where id=${first}`;
      assert.equal(r.target_type, "message");
      assert.equal(r.conversation_id, p.conv);
      assert.equal(r.evidence.content, "Me paga por fora pelo Pix");
      assert.equal(r.evidence.sender_id, p.worker);
      await assert.rejects(
        asUser(
          db,
          p.client,
          (tx) => tx`select public.report_message(${own},'spam',null)`,
        ),
        /MESSAGE_NOT_FOUND/,
      );
      const outsider = (await customer(db)).userId;
      await assert.rejects(
        asUser(
          db,
          outsider,
          (tx) => tx`select public.report_message(${msg},'spam',null)`,
        ),
        /MESSAGE_NOT_FOUND/,
      );
      await assert.rejects(
        asUser(
          db,
          p.client,
          (tx) => tx`select public.report_message(${msg},'invalido',null)`,
        ),
        /reports_reason_check|violates check/,
      );
      // Inserção direta de denúncia de mensagem (sem passar pela função) é recusada.
      await assert.rejects(
        asUser(
          db,
          p.client,
          (tx) =>
            tx`insert into public.reports (target_type,target_id,reason)
        values ('message',${msg},'spam')`,
        ),
        /row-level security/,
      );
      await asUser(
        db,
        p.client,
        (tx) =>
          tx`insert into public.reports (target_type,target_id,reason)
      values ('profile',${p.worker},'spam')`,
      );
    },
  );

  await t.step(
    "chat: moderação vê o trecho e o remetente da mensagem denunciada",
    async () => {
      await reset(db);
      const p = await pair(db);
      const mod = await admin(db);
      const msg = await send(db, p.worker, p.conv, "Conteúdo ofensivo");
      await asUser(
        db,
        p.client,
        (tx) => tx`select public.report_message(${msg},'offensive',null)`,
      );
      const rows = await asUser(
        db,
        mod,
        (tx) => tx`select * from public.admin_list_reports('open')`,
      );
      assert.equal(rows.length, 1);
      assert.equal(rows[0].target_type, "message");
      assert.equal(rows[0].target_id, p.worker, "alvo da ação é quem enviou");
      assert.match(rows[0].target_label, /Conteúdo ofensivo/);
    },
  );
}
