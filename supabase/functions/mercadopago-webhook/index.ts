import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

async function verifyMercadoPagoHmac(
  xSignature: string | null,
  xRequestId: string | null,
  dataId: string | null,
  secret: string
): Promise<boolean> {
  if (!xSignature || !xRequestId || !dataId || !secret) return false;

  try {
    const parts = xSignature.split(",");
    let ts = "";
    let v1 = "";

    for (const part of parts) {
      const [key, value] = part.trim().split("=");
      if (key === "ts") ts = value;
      if (key === "v1") v1 = value;
    }

    if (!ts || !v1) return false;

    // Manifest template oficial Mercado Pago:
    // id:[data.id];request-id:[x-request-id];ts:[ts];
    const manifest = `id:${dataId};request-id:${xRequestId};ts:${ts};`;

    const encoder = new TextEncoder();
    const keyData = encoder.encode(secret);
    const msgData = encoder.encode(manifest);

    const cryptoKey = await crypto.subtle.importKey(
      "raw",
      keyData,
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"]
    );

    const signatureBuffer = await crypto.subtle.sign("HMAC", cryptoKey, msgData);
    const hashArray = Array.from(new Uint8Array(signatureBuffer));
    const calculatedHex = hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");

    if (calculatedHex.length !== v1.length) return false;
    let match = 0;
    for (let i = 0; i < calculatedHex.length; i++) {
      match |= calculatedHex.charCodeAt(i) ^ v1.charCodeAt(i);
    }
    return match === 0;
  } catch (e) {
    console.error("[HMAC Verification Exception]:", e);
    return false;
  }
}

serve(async (req: Request) => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "https://wmfsjitjqltzbbgynwfb.supabase.co";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const mpAccessToken = Deno.env.get("MERCADO_PAGO_ACCESS_TOKEN");
    const mpWebhookSecret = Deno.env.get("MERCADO_PAGO_WEBHOOK_SECRET");

    if (!supabaseServiceKey) {
      console.error("ERRO CRÍTICO: SUPABASE_SERVICE_ROLE_KEY não configurada.");
      return new Response(JSON.stringify({ error: "Configuração do servidor ausente." }), { status: 500 });
    }

    if (!mpAccessToken) {
      console.error("ERRO CRÍTICO: MERCADO_PAGO_ACCESS_TOKEN não configurada nas Secrets.");
      return new Response(JSON.stringify({ error: "Configuração de pagamento ausente." }), { status: 500 });
    }

    const url = new URL(req.url);
    let paymentId: string | null = null;

    // 1. Tentar capturar ID via query params (formato V1 / Webhook clássico)
    const idFromQuery = url.searchParams.get("id") || url.searchParams.get("data.id");
    if (idFromQuery) {
      paymentId = idFromQuery;
    }

    // 2. Se não veio na query, ler o corpo da requisição JSON (formato V2 / IPN)
    let requestBody: any = null;
    if (req.method === "POST") {
      try {
        requestBody = await req.json();
        if (!paymentId) {
          paymentId = requestBody?.data?.id || requestBody?.id || null;
        }
      } catch (_) {
        // Body não é JSON
      }
    }

    if (!paymentId) {
      // Retorna 200 para testes de ping do Mercado Pago
      return new Response(JSON.stringify({ message: "Ping recebido ou nenhum payment_id presente." }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 3. Validação Criptográfica HMAC da Assinatura (se webhook secret estiver provisionada)
    const xSignature = req.headers.get("x-signature");
    const xRequestId = req.headers.get("x-request-id");

    if (mpWebhookSecret && xSignature && xRequestId) {
      const isValidHmac = await verifyMercadoPagoHmac(xSignature, xRequestId, paymentId, mpWebhookSecret);
      if (!isValidHmac) {
        console.warn(`[Webhook MP] Assinatura HMAC inválida para pagamento ID ${paymentId}`);
        return new Response(JSON.stringify({ error: "Assinatura de webhook não autorizada." }), {
          status: 401,
          headers: { "Content-Type": "application/json" },
        });
      }
      console.log(`[Webhook MP] Assinatura HMAC validada com sucesso para pagamento ID ${paymentId}`);
    }

    console.log(`[Webhook MP] Consultando estado autêntico do pagamento ID: ${paymentId}`);

    // 4. Consultar a API oficial do Mercado Pago para obter os dados oficiais
    const mpResponse = await fetch(`https://api.mercadopago.com/v1/payments/${paymentId}`, {
      method: "GET",
      headers: {
        "Authorization": `Bearer ${mpAccessToken}`,
        "Content-Type": "application/json",
      },
    });

    if (!mpResponse.ok) {
      console.error(`Erro ao consultar pagamento ${paymentId} na API do MP:`, await mpResponse.text());
      return new Response("Payment not found on MP", { status: 200 }); // 200 para não travar a fila de retry do MP
    }

    const mpData = await mpResponse.json();
    const mpStatus = mpData.status;
    const amount = Number(mpData.transaction_amount);
    const gatewayRef = mpData.id.toString();
    const contractIdFromMeta = mpData.metadata?.contract_id || mpData.external_reference || null;

    console.log(`[Webhook MP] Pagamento ${gatewayRef} com status oficial: ${mpStatus}, valor: ${amount}`);

    const supabaseClient = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false },
    });

    // 5. Validação de consistência do Contrato se referenciado
    if (contractIdFromMeta) {
      const { data: contractRecord, error: contractErr } = await supabaseClient
        .from("contracts")
        .select("id, total_amount, status")
        .eq("id", contractIdFromMeta)
        .maybeSingle();

      if (contractErr) {
        console.error(`[Webhook MP] Erro ao consultar contrato ${contractIdFromMeta}:`, contractErr);
      } else if (contractRecord) {
        console.log(`[Webhook MP] Contrato vinculado encontrado: ${contractRecord.id}, status atual: ${contractRecord.status}`);
      }
    }

    // 6. Se o pagamento foi APROVADO, ativar o Escrow e o Contrato de forma atômica e idempotente
    if (mpStatus === "approved") {
      const { data, error } = await supabaseClient.rpc("confirm_escrow_deposit", {
        p_gateway_ref: gatewayRef,
        p_paid_amount: amount,
        p_gateway_status: mpStatus,
        p_metadata: {
          contract_id: contractIdFromMeta,
          webhook_received_at: new Date().toISOString(),
          payment_type: mpData.payment_type_id,
          payment_method_id: mpData.payment_method_id,
          collector_id: mpData.collector_id,
          external_reference: mpData.external_reference,
        },
      });

      if (error) {
        console.error("[Webhook MP] Erro ao executar confirm_escrow_deposit:", error);
      } else {
        console.log(`[Webhook MP] Escrow ativado com sucesso para pagamento ${gatewayRef}:`, data);
      }
    } else if (mpStatus === "rejected" || mpStatus === "cancelled" || mpStatus === "refunded") {
      await supabaseClient
        .from("transactions")
        .update({
          status: mpStatus === "refunded" ? "refunded" : "failed",
          gateway_status: mpStatus,
          metadata: {
            status_detail: mpData.status_detail,
            updated_at: new Date().toISOString(),
          },
          updated_at: new Date().toISOString(),
        })
        .eq("gateway_ref", gatewayRef);
    }

    return new Response(JSON.stringify({ success: true, processed_id: gatewayRef, status: mpStatus }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err: any) {
    console.error("[Webhook MP Exception]:", err);
    const errMsg = err instanceof Error ? err.message : String(err?.message || err);
    return new Response(JSON.stringify({ error: errMsg }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }
});
