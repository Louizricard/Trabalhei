import { adminClient, env, json, reportError } from "../_shared/common.ts";
import { createWebhookHandler, type ProcessingResult } from "./handler.ts";

Deno.serve(createWebhookHandler({
  token: () => env("ASAAS_WEBHOOK_TOKEN"),
  reply: json,
  report: (error, extra) => reportError("asaas-webhook", error, extra),
  receive: async (payload) => {
    const { data, error } = await adminClient().rpc(
      "receive_asaas_billing_event",
      {
        p_payload: payload,
      },
    );
    if (error) throw error;
    return data as ProcessingResult;
  },
}));
