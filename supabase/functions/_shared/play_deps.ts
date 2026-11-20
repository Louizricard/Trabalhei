// Dependências reais (Google + banco) das funções play-billing e play-rtdn.
import { adminClient, env, HttpError } from "./common.ts";
import { googlePlay } from "./google_play.ts";
import { type PlayDeps, PurchaseError } from "./play_purchases.ts";

const KNOWN: Record<string, [number, string]> = {
  PURCHASE_OWNED_BY_OTHER: [403, "Esta compra pertence a outra conta."],
  JOB_NOT_FOUND: [400, "Vaga não encontrada."],
  ACCOUNT_UNAVAILABLE: [401, "Conta indisponível."],
  PURCHASE_PRODUCT_CONFLICT: [400, "Compra de outro produto."],
};

export function playDeps(): PlayDeps {
  const admin = adminClient();
  return {
    play: googlePlay(env("GOOGLE_PLAY_SERVICE_ACCOUNT")),
    rpc: async (name, args) => {
      const { data, error } = await admin.rpc(name, args);
      if (error) {
        const known = Object.keys(KNOWN).find((k) => error.message?.includes(k));
        if (known) throw new PurchaseError(...KNOWN[known]);
        throw new HttpError(500, "Falha ao registrar a compra.", { cause: error });
      }
      return (data ?? {}) as Record<string, unknown>;
    },
  };
}
