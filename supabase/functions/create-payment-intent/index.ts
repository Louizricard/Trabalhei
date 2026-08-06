import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface PaymentIntentRequest {
  contract_id?: string;
  amount?: number;
  payment_method: "pix" | "credit_card";
  description?: string;
  // Tokenização segura de Cartão de Crédito
  token?: string;
  installments?: number;
  payment_method_id?: string;
  payer_cpf?: string;
  payer_name?: string;
  payer_email?: string;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "https://wmfsjitjqltzbbgynwfb.supabase.co";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const mpAccessToken = Deno.env.get("MERCADO_PAGO_ACCESS_TOKEN");

    if (!supabaseServiceKey) {
      console.error("ERRO CRÍTICO: SUPABASE_SERVICE_ROLE_KEY não configurada.");
      return new Response(JSON.stringify({ error: "Configuração do servidor ausente." }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!mpAccessToken) {
      console.error("ERRO CRÍTICO: MERCADO_PAGO_ACCESS_TOKEN não configurada nas Secrets.");
      return new Response(JSON.stringify({ error: "Configuração de pagamento ausente." }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const webhookBaseUrl = Deno.env.get("WEBHOOK_BASE_URL") ?? `${supabaseUrl}/functions/v1/mercadopago-webhook`;

    // 1. Validar autenticação do usuário
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Não autorizado" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseClient = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false },
    });

    const jwtToken = authHeader.replace("Bearer ", "");
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser(jwtToken);

    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Sessão inválida ou expirada" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body: PaymentIntentRequest = await req.json();
    const {
      contract_id,
      payment_method,
      description,
      token: cardToken,
      installments,
      payment_method_id,
      payer_cpf,
      payer_name,
      payer_email,
    } = body;

    let finalAmount = body.amount ? Number(body.amount) : 0;

    // 2. Validação Rigorosa de Contrato e Valor no Banco de Dados
    if (contract_id) {
      const { data: contract, error: contractErr } = await supabaseClient
        .from("contracts")
        .select("id, client_id, total_amount, status")
        .eq("id", contract_id)
        .single();

      if (contractErr || !contract) {
        return new Response(JSON.stringify({ error: "Contrato não encontrado." }), {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // Validação de autoridade
      if (contract.client_id !== user.id) {
        return new Response(JSON.stringify({ error: "Acesso negado: você não é o cliente deste contrato." }), {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // Validação de estado
      if (contract.status !== "awaiting_payment") {
        return new Response(JSON.stringify({
          error: `Este contrato já está no status '${contract.status}' e não aceita novo pagamento inicial.`,
        }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // SEMPRE SOBRESCREVER COM O VALOR OFICIAL DO CONTRATO DO BANCO
      finalAmount = Number(contract.total_amount);
    }

    if (!finalAmount || finalAmount <= 0) {
      return new Response(JSON.stringify({ error: "Valor de pagamento inválido." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const userEmail = payer_email || user.email || "cliente@trabalhei.com.br";
    const cleanCpf = payer_cpf ? payer_cpf.replace(/\D/g, "") : "";
    const clientName = payer_name || user.user_metadata?.full_name || "Cliente Trabalhei";

    // 3. Processar Pagamento PIX com Mercado Pago Produção
    if (payment_method === "pix") {
      try {
        const mpPayload: Record<string, any> = {
          transaction_amount: Number(finalAmount.toFixed(2)),
          description: description || `Garantia de Escrow FreelanceFlow - ${contract_id ? `Contrato #${contract_id.substring(0, 8)}` : "Depósito"}`,
          payment_method_id: "pix",
          notification_url: webhookBaseUrl,
          external_reference: contract_id || `dep_${user.id}_${Date.now()}`,
          payer: {
            email: userEmail,
            first_name: clientName.split(" ")[0] || "Cliente",
            last_name: clientName.split(" ").slice(1).join(" ") || "FreelanceFlow",
          },
          metadata: {
            user_id: user.id,
            contract_id: contract_id || null,
            platform: "freelanceflow",
          },
        };

        if (cleanCpf && cleanCpf.length === 11) {
          mpPayload.payer.identification = {
            type: "CPF",
            number: cleanCpf,
          };
        }

        const mpResponse = await fetch("https://api.mercadopago.com/v1/payments", {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${mpAccessToken}`,
            "Content-Type": "application/json",
            "X-Idempotency-Key": `pix_${user.id}_${contract_id || 'wallet'}_${Date.now()}`,
          },
          body: JSON.stringify(mpPayload),
        });

        const mpData = await mpResponse.json();

        if (mpResponse.ok && mpData.id) {
          const pointOfInteraction = mpData.point_of_interaction?.transaction_data;
          const qrCode = pointOfInteraction?.qr_code || "";
          const qrCodeBase64 = pointOfInteraction?.qr_code_base64 || "";
          const gatewayRef = mpData.id.toString();

          // Registrar transação pendente via service_role
          const { data: tx, error: txError } = await supabaseClient.from("transactions").insert({
            user_id: user.id,
            contract_id: contract_id || null,
            type: "deposit",
            amount: finalAmount,
            status: "pending",
            gateway_provider: "mercadopago",
            gateway_ref: gatewayRef,
            gateway_status: mpData.status || "pending",
            payment_method: "pix",
            metadata: {
              qr_code: qrCode,
              qr_code_base64: qrCodeBase64,
              ticket_url: pointOfInteraction?.ticket_url,
              mp_created_at: mpData.date_created,
            },
          }).select().single();

          if (txError) {
            console.error("[PIX Transaction Insert Error]:", txError);
          }

          return new Response(JSON.stringify({
            success: true,
            transaction_id: tx?.id,
            gateway_ref: gatewayRef,
            status: "pending",
            payment_method: "pix",
            amount: finalAmount,
            qr_code: qrCode,
            qr_code_base64: qrCodeBase64,
            expires_at: mpData.date_of_expiration,
          }), {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        } else {
          console.error("[Mercado Pago PIX Error]:", mpData);
          const errorDetail = mpData?.message || mpData?.cause?.[0]?.description || "Erro ao gerar cobrança PIX.";
          return new Response(JSON.stringify({ error: errorDetail }), {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }
      } catch (pixErr: any) {
        console.error("[PIX Exception]:", pixErr);
        const errMsg = pixErr instanceof Error ? pixErr.message : String(pixErr?.message || pixErr);
        return new Response(JSON.stringify({ error: errMsg }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    // 4. Processar Pagamento CARTÃO DE CRÉDITO Tokenizado
    if (payment_method === "credit_card") {
      if (!cardToken) {
        return new Response(JSON.stringify({
          error: "Token do cartão não fornecido. O cartão deve ser tokenizado no dispositivo.",
        }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      try {
        const mpPayload: Record<string, any> = {
          transaction_amount: Number(finalAmount.toFixed(2)),
          token: cardToken,
          description: description || `Garantia de Escrow FreelanceFlow - ${contract_id ? `Contrato #${contract_id.substring(0, 8)}` : "Depósito"}`,
          installments: installments || 1,
          payment_method_id: payment_method_id,
          notification_url: webhookBaseUrl,
          external_reference: contract_id || `card_${user.id}_${Date.now()}`,
          payer: {
            email: userEmail,
            ...(cleanCpf && cleanCpf.length === 11 ? { identification: { type: "CPF", number: cleanCpf } } : {}),
          },
          metadata: {
            user_id: user.id,
            contract_id: contract_id || null,
            platform: "freelanceflow",
          },
        };

        const mpResponse = await fetch("https://api.mercadopago.com/v1/payments", {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${mpAccessToken}`,
            "Content-Type": "application/json",
            "X-Idempotency-Key": `card_${user.id}_${contract_id || 'wallet'}_${Date.now()}`,
          },
          body: JSON.stringify(mpPayload),
        });

        const mpData = await mpResponse.json();

        if (mpResponse.ok && mpData.id) {
          const mpStatus = mpData.status;
          const gatewayRef = mpData.id.toString();

          let transactionStatus = "pending";
          if (mpStatus === "approved") {
            transactionStatus = "completed";
          } else if (mpStatus === "rejected" || mpStatus === "cancelled") {
            transactionStatus = "failed";
          }

          // Registrar transação
          const { data: tx } = await supabaseClient.from("transactions").insert({
            user_id: user.id,
            contract_id: contract_id || null,
            type: "deposit",
            amount: finalAmount,
            status: transactionStatus,
            gateway_provider: "mercadopago",
            gateway_ref: gatewayRef,
            gateway_status: mpStatus,
            payment_method: "credit_card",
            metadata: {
              card_last_four_digits: mpData.card?.last_four_digits,
              cardholder: mpData.card?.cardholder?.name,
              installments: mpData.installments,
              status_detail: mpData.status_detail,
              payment_method_id: mpData.payment_method_id,
            },
          }).select().single();

          // SE FOI APROVADO NA HORA, ATIVAR ESCROW E CONTRATO IMEDIATAMENTE
          if (mpStatus === "approved") {
            await supabaseClient.rpc("confirm_escrow_deposit", {
              p_gateway_ref: gatewayRef,
              p_paid_amount: finalAmount,
              p_gateway_status: mpStatus,
              p_metadata: {
                contract_id: contract_id || null,
                payment_type: "credit_card",
                instant_approval: true,
              },
            });
          }

          return new Response(JSON.stringify({
            success: mpStatus === "approved",
            transaction_id: tx?.id,
            gateway_ref: gatewayRef,
            status: transactionStatus,
            gateway_status: mpStatus,
            status_detail: mpData.status_detail,
            payment_method: "credit_card",
            amount: finalAmount,
          }), {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        } else {
          console.error("[Mercado Pago Card Payment Error]:", mpData);
          const errorDetail = mpData?.message || mpData?.cause?.[0]?.description || "Cartão não autorizado ou recusado.";
          return new Response(JSON.stringify({
            error: errorDetail,
            status_detail: mpData?.status_detail,
          }), {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }
      } catch (cardErr: any) {
        console.error("[Card Exception]:", cardErr);
        const errMsg = cardErr instanceof Error ? cardErr.message : String(cardErr?.message || cardErr);
        return new Response(JSON.stringify({ error: errMsg }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    return new Response(JSON.stringify({ error: "Método de pagamento não suportado." }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err: any) {
    console.error("[Create Payment Intent Error]:", err);
    const errMsg = err instanceof Error ? err.message : String(err?.message || err);
    return new Response(JSON.stringify({ error: errMsg }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
