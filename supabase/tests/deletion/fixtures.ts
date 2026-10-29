import { customer, type Database, sqlFile } from "../webhook/fixtures.ts";
import {
  deleteAccount,
  type DeletionDependencies,
  type DeletionRequest,
} from "../../functions/delete-account/workflow.ts";

export const deletionMigrations = [
  "20261029182207_account_deletion_state",
  "20261029182209_account_deletion_cleanup",
  "20261029182211_account_deletion_access",
  "20261029182213_account_deletion_storage",
];
const base = new URL("../../", import.meta.url);

export async function installDeletion(db: Database) {
  await db`alter table storage.objects add column owner_id text`;
  for (
    const name of [
      "20261023160420_account_deletion",
      "20261025190601_profile_details_and_resumes",
      "20261024182531_private_chat_attachments",
      "20261026104955_guest_browsing",
    ]
  ) await sqlFile(db, `migrations/${name}.sql`);
  const admins = await Deno.readTextFile(
    new URL("migrations/20261026110842_admin_moderation.sql", base),
  );
  await db.unsafe(
    admins.slice(0, admins.indexOf("create function public.is_admin")),
  );
  await db`alter table public.profiles add column suspended_at timestamptz`;
  const delivery = await Deno.readTextFile(
    new URL("migrations/20261026110910_notification_delivery.sql", base),
  );
  // Estruturas reais; pg_net/Vault/entrega externa ficam fora do banco descartável.
  await db.unsafe(
    delivery.slice(
      delivery.indexOf("create table public.notification_settings"),
      delivery.indexOf("-- Marca de entrega"),
    ),
  );
  await sqlFile(db, "migrations/20261026110913_job_alerts.sql");
  await db.unsafe(`alter table storage.objects enable row level security;
    grant usage on schema storage to anon,authenticated,service_role;
    grant select,insert,update,delete on storage.objects to anon,authenticated,service_role;
    grant select on public.profiles,public.jobs,public.proposals,public.contracts,public.conversations,
      public.milestones,public.messages,public.notifications,public.portfolio_items,public.reviews to anon,authenticated;
    grant select on public.admins,public.push_subscriptions,public.notification_settings,public.job_alerts to authenticated;
    grant select on public.webhook_test_failures to authenticated;
    grant all on all tables in schema public to service_role;`);
  for (const name of deletionMigrations) {
    await sqlFile(db, `migrations/${name}.sql`);
  }
}

export async function contract(db: Database, status = "completed") {
  const client = await customer(db), freelancer = await customer(db);
  await db`update public.profiles set role='freelancer' where id=${freelancer.userId}`;
  const [proposal] =
    await db`insert into public.proposals(job_id,freelancer_id,bid_amount,estimated_days,cover_letter,status)
    values(${client.jobId},${freelancer.userId},100,7,'Proposta de teste da exclusão','accepted') returning id`;
  const [row] =
    await db`insert into public.contracts(job_id,proposal_id,client_id,freelancer_id,total_amount,estimated_days,status)
    values(${client.jobId},${proposal.id},${client.userId},${freelancer.userId},100,7,${status}) returning id`;
  return { client, freelancer, contractId: row.id as string };
}
export async function personalProfile(db: Database, id: string) {
  await db`update public.profiles set full_name='Nome privado',headline='Título privado',location='Cidade privada',
    website_url='https://example.invalid/site',linkedin_url='https://example.invalid/in',github_url='https://example.invalid/git',
    resume_url='https://example.invalid/cv.pdf',avatar_url='avatar-private',company_name='Empresa privada',bio='Bio privada',
    hourly_rate=25,skills=array['skill-private'],is_verified=true,plan='pro',plan_expires_at=now()+interval '30 days' where id=${id}`;
}
export async function object(
  db: Database,
  user: string,
  bucket = "resumes",
  name = `${user}/nested/cv.pdf`,
  owned = true,
) {
  await db`insert into storage.objects(id,bucket_id,name,owner,owner_id)
    values(${crypto.randomUUID()},${bucket},${name},${owned ? user : null},${
    owned ? user : null
  })`;
  return { bucket_id: bucket, name };
}
export async function begin(
  db: Database,
  user: string,
): Promise<DeletionRequest> {
  const [r] = await db`select public.begin_account_deletion(${user}) r`;
  return r.r;
}
export function dependencies(db: Database, user: string) {
  const faults = new Set<string>(), calls: string[] = [];
  const erased: boolean[] = [];
  const check = (name: string) => {
    calls.push(name);
    if (faults.delete(name)) throw new Error(`Injected ${name}`);
  };
  const deps: DeletionDependencies = {
    authorize: () => Promise.resolve(user),
    begin: (u) => begin(db, u),
    cancelBilling: async () => {
      check("billing");
    },
    objects: async (u, t) => {
      check("list");
      const rows =
        await db`select * from public.account_deletion_objects(${u},${t})`;
      return [...rows] as never;
    },
    remove: async (b, n) => {
      check("remove");
      await db`delete from storage.objects where bucket_id=${b} and name in ${
        db(n)
      }`;
    },
    prepareAuth: async (u, t) => {
      check("data");
      await db`select public.prepare_account_auth_deletion(${u},${t})`;
    },
    eraseAuth: async (u, soft) => {
      check("auth");
      erased.push(soft);
      if (soft) {
        await db`update auth.users set email='deleted@example.invalid',raw_user_meta_data='{}' where id=${u}`;
      } else await db`delete from auth.users where id=${u}`;
    },
    complete: async (u, t) => {
      check("complete");
      await db`select public.complete_account_deletion(${u},${t})`;
    },
    fail: async (u, t, s) => {
      await db`select public.fail_account_deletion(${u},${t},${s})`;
    },
    report: () => Promise.resolve(),
    reply: (body, status = 200) => Response.json(body, { status }),
  };
  return { deps, faults, calls, erased, run: () => deleteAccount(user, deps) };
}
