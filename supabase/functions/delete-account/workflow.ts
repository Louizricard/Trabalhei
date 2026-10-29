export class DeletionError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
  }
}
export interface DeletionRequest {
  token: string;
  hard_delete: boolean;
  phase: string;
  completed?: boolean;
}
export interface StoredObject {
  bucket_id: string;
  name: string;
}
export interface DeletionDependencies {
  authorize: (request: Request) => Promise<string>;
  begin: (user: string) => Promise<DeletionRequest>;
  cancelBilling: (user: string) => Promise<void>;
  objects: (user: string, token: string) => Promise<StoredObject[]>;
  remove: (bucket: string, names: string[]) => Promise<void>;
  prepareAuth: (user: string, token: string) => Promise<void>;
  eraseAuth: (user: string, soft: boolean) => Promise<void>;
  complete: (user: string, token: string) => Promise<void>;
  fail: (user: string, token: string, step: string) => Promise<void>;
  report: (step: string) => Promise<void>;
  reply: (body: unknown, status?: number) => Response;
  now?: () => number;
}

async function removeObjects(
  user: string,
  token: string,
  deps: DeletionDependencies,
) {
  const now = deps.now ?? Date.now;
  const deadline = now() + 40_000;
  let previous = "";
  while (true) {
    if (now() > deadline) throw new Error("STORAGE_TIME_BUDGET");
    const objects = await deps.objects(user, token);
    if (!Array.isArray(objects)) throw new Error("STORAGE_MANIFEST_INVALID");
    if (!objects.length) return;
    const fingerprint = JSON.stringify(objects);
    if (fingerprint === previous) throw new Error("STORAGE_NO_PROGRESS");
    previous = fingerprint;
    const buckets = new Map<string, string[]>();
    for (const object of objects) {
      const names = buckets.get(object.bucket_id) ?? [];
      names.push(object.name);
      buckets.set(object.bucket_id, names);
    }
    for (const [bucket, names] of buckets) await deps.remove(bucket, names);
  }
}

export async function deleteAccount(user: string, deps: DeletionDependencies) {
  const request = await deps.begin(user);
  if (request.completed) return;
  let step = "billing";
  try {
    await deps.cancelBilling(user);
    step = "storage";
    await removeObjects(user, request.token, deps);
    step = "data";
    await deps.prepareAuth(user, request.token);
    step = "auth";
    await deps.eraseAuth(user, !request.hard_delete);
    step = "complete";
    await deps.complete(user, request.token);
  } catch {
    await deps.fail(user, request.token, step).catch(() => {});
    await deps.report(step).catch(() => {});
    throw new DeletionError(
      503,
      "A exclusão não foi concluída. Tente novamente ou fale com o suporte para retomar a limpeza.",
    );
  }
}
