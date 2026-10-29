import {
  deleteAccount,
  type DeletionDependencies,
  DeletionError,
} from "./workflow.ts";

export function createDeletionHandler(deps: DeletionDependencies) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return deps.reply({ ok: true });
    if (req.method !== "POST") {
      return deps.reply({ error: "Método não permitido." }, 405);
    }
    try {
      const user = await deps.authorize(req);
      await deleteAccount(user, deps);
      return deps.reply({ ok: true });
    } catch (error) {
      if (error instanceof DeletionError) {
        return deps.reply({ error: error.message }, error.status);
      }
      await deps.report("request").catch(() => {});
      return deps.reply({
        error: "Não foi possível iniciar a exclusão. Tente novamente.",
      }, 503);
    }
  };
}
