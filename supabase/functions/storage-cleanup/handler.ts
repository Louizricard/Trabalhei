// Apaga arquivos órfãos do Storage em lotes (ver migration
// 20261113185537_storage_cleanup_queue). Só aceita a chave service_role:
// deve ser chamada por um agendamento (Cron do Supabase), nunca pelo app.

export type StoredPath = { bucket: string; path: string };

export interface CleanupDependencies {
  authorize(req: Request): Promise<boolean>;
  batch(limit: number): Promise<StoredPath[]>;
  remove(bucket: string, paths: string[]): Promise<void>;
  report(done: StoredPath[], failed: StoredPath[], error: string | null): Promise<void>;
  reply(body: unknown, status?: number): Response;
}

export const BATCH_SIZE = 100;

export function createCleanupHandler(deps: CleanupDependencies) {
  return async (req: Request): Promise<Response> => {
    if (req.method !== "POST") {
      return deps.reply({ error: "Método não permitido." }, 405);
    }
    if (!(await deps.authorize(req))) {
      return deps.reply({ error: "Não autorizado." }, 401);
    }
    const items = await deps.batch(BATCH_SIZE);
    const byBucket = new Map<string, string[]>();
    for (const item of items) {
      byBucket.set(item.bucket, [...(byBucket.get(item.bucket) ?? []), item.path]);
    }
    const done: StoredPath[] = [], failed: StoredPath[] = [];
    let lastError: string | null = null;
    for (const [bucket, paths] of byBucket) {
      const group = paths.map((path) => ({ bucket, path }));
      try {
        await deps.remove(bucket, paths);
        done.push(...group);
      } catch (error) {
        failed.push(...group);
        lastError = String(error);
      }
    }
    await deps.report(done, failed, lastError);
    return deps.reply({ removed: done.length, failed: failed.length });
  };
}
