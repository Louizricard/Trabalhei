export interface ProcessingResult {
  status: "processed" | "ignored" | "legacy" | "pending" | "failed";
  duplicate?: boolean;
  error_code?: string;
}

interface Dependencies {
  token: () => string;
  receive: (payload: Record<string, unknown>) => Promise<ProcessingResult>;
  reply: (body: unknown, status?: number) => Response;
  report: (error: unknown, extra: Record<string, unknown>) => Promise<void>;
}

function timingSafeEqual(a: string, b: string): boolean {
  const encoder = new TextEncoder();
  const left = encoder.encode(a);
  const right = encoder.encode(b);
  if (left.length !== right.length) return false;
  let diff = 0;
  for (let i = 0; i < left.length; i++) diff |= left[i] ^ right[i];
  return diff === 0;
}

function validEvent(body: unknown): body is Record<string, unknown> {
  if (!body || typeof body !== "object" || Array.isArray(body)) return false;
  const event = body as Record<string, unknown>;
  if (
    typeof event.id !== "string" || !event.id.trim() || event.id.length > 200
  ) return false;
  if (
    typeof event.event !== "string" || !event.event.trim() ||
    event.event.length > 100
  ) return false;
  if (
    ["PAYMENT_CONFIRMED", "PAYMENT_RECEIVED", "PAYMENT_REFUNDED"].includes(
      event.event,
    )
  ) {
    const payment = event.payment as Record<string, unknown> | undefined;
    return !!payment && typeof payment.id === "string" && !!payment.id.trim();
  }
  return true;
}

async function processingResponse(
  result: ProcessingResult,
  payload: Record<string, unknown>,
  deps: Dependencies,
): Promise<Response> {
  if (result?.status === "pending" || result?.status === "failed") {
    await deps.report(
      new Error("Evento de cobrança pendente de processamento."),
      {
        eventId: payload.id,
        event: payload.event,
        status: result.status,
        code: result.error_code,
      },
    );
    return deps.reply(
      { error: "Processamento pendente. Reenvie o evento." },
      503,
    );
  }
  if (!["processed", "ignored", "legacy"].includes(result?.status)) {
    throw new Error("Resposta inválida do processamento de cobrança.");
  }
  return deps.reply({ ok: true, duplicate: result.duplicate ?? false });
}

async function processRequest(
  req: Request,
  deps: Dependencies,
): Promise<Response> {
  if (
    !timingSafeEqual(req.headers.get("asaas-access-token") ?? "", deps.token())
  ) {
    return deps.reply({ error: "Token inválido." }, 401);
  }
  const payload: unknown = await req.json().catch(() => null);
  if (!validEvent(payload)) {
    return deps.reply({ error: "Evento inválido." }, 400);
  }
  return processingResponse(await deps.receive(payload), payload, deps);
}

export function createWebhookHandler(deps: Dependencies) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return deps.reply({ ok: true });
    if (req.method !== "POST") {
      return deps.reply({ error: "Método não permitido." }, 405);
    }
    try {
      return await processRequest(req, deps);
    } catch (error) {
      await deps.report(error, { step: "receive_asaas_billing_event" }).catch(
        () => {},
      );
      return deps.reply({ error: "Falha ao processar." }, 500);
    }
  };
}
