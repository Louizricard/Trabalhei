import { asUser, type Database } from "../webhook/fixtures.ts";

export const uploadLimitsMigration = "20261113120000_plan_upload_limits";

const MB = 1024 * 1024;
const base = "https://projeto.supabase.co/storage/v1/object/public";

export async function prepareStorage(db: Database) {
  await db`alter table storage.objects add column if not exists metadata jsonb`;
}

// Simula um arquivo já enviado ao Storage e devolve o item como o app o grava.
export async function stored(
  db: Database,
  owner: string,
  bucket: string,
  mb = 1,
) {
  const name = `${owner}/teste/${crypto.randomUUID()}_arquivo.pdf`;
  await db`insert into storage.objects (id,bucket_id,name,owner,metadata)
    values (gen_random_uuid(),${bucket},${name},${owner},
      ${db.json({ size: Math.round(mb * MB), mimetype: "application/pdf" })})`;
  return {
    id: crypto.randomUUID(),
    name: "arquivo.pdf",
    url: `${base}/${bucket}/${name}`,
    size: Math.round(mb * MB),
    mime_type: "application/pdf",
  };
}

export async function makePro(db: Database, user: string, active = true) {
  await db`update public.profiles set plan='pro',
    plan_expires_at=now() + ${active ? "30 days" : "-1 day"}::interval
    where id=${user}`;
}

export function setJobAttachments(
  db: Database,
  user: string,
  jobId: string,
  items: unknown[],
) {
  return asUser(
    db,
    user,
    (tx) =>
      tx`update public.jobs set attachments=${
        tx.json(items as never)
      } where id=${jobId}`,
  );
}
