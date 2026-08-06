import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "https://wmfsjitjqltzbbgynwfb.supabase.co";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const mpAccessToken = Deno.env.get("MERCADO_PAGO_ACCESS_TOKEN");

    if (!supabaseServiceKey || !mpAccessToken) {
      console.error("Configurações essenciais ausentes (SUPABASE_SERVICE_ROLE_KEY ou MERCADO_PAGO_ACCESS_TOKEN).");
      return new Response(JSON.stringify({ error: "Configuração do servidor ausente." }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

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

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser(token);

    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Sessão inválida" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json().catch(() => ({}));
    const gatewayRef = body.gateway_ref?.toString() || body.payment_id?.toString();
    const transactionId = body.transaction_id;

    let targetGatewayRef = gatewayRef;

    // Se passou apenas transaction_id, buscar o gateway_ref no banco
    if (!targetGatewayRef && transactionId) {
      const { data: tx } = await supabaseClient
        .from("transactions")
        .select("gateway_ref, status")
        .eq("id", transactionId)
        .eq("user_id", user.id)
        .single();
      if (tx?.gateway_ref) {
        targetGatewayRef = tx.gateway_ref;
      }
    }

    if (!targetGatewayRef) {
      // Se não passou gateway_ref nem transaction_id, buscar a última transação pendente do usuário
      const { data: lastTx } = await supabaseClient
        .from("transactions")
        .select("id, gateway_ref, status, amount, contract_id")
        .eq("user_id", user.id)
        .order("created_at", { ascending: false })
        .limit(1)
        .single();

      if (lastTx?.gateway_ref) {
        targetGatewayRef = lastTx.gateway_ref;
      }
    }

    if (!targetGatewayRef) {
      return new Response(JSON.stringify({ error: "gateway_ref ou transaction_id obrigatório" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Consultar a API do Mercado Pago
    const mpResponse = await fetch(`https://api.mercadopago.com/v1/payments/${targetGatewayRef}`, {
      method: "GET",
      headers: {
        "Authorization": `Bearer ${mpAccessToken}`,
        "Content-Type": "application/json",
      },
    });

    if (!mpResponse.ok) {
      const errorText = await mpResponse.text();
      console.error(`Erro ao consultar MP para ID ${targetGatewayRef}:`, errorText);
      return new Response(JSON.stringify({ error: "Pagamento não encontrado no Mercado Pago", details: errorText }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const mpData = await mpResponse.json();
    const mpStatus = mpData.status; // 'approved', 'pending', 'in_process', 'rejected', 'cancelled'
    const amount = Number(mpData.transaction_amount);
    const contractIdFromMeta = mpData.metadata?.contract_id || mpData.external_reference || null;

    let transactionStatus = "pending";
    if (mpStatus === "approved") {
      transactionStatus = "completed";
    } else if (mpStatus === "rejected" || mpStatus === "cancelled") {
      transactionStatus = "failed";
    }

    // Se aprovado, executar ativação atômica de escrow
    if (mpStatus === "approved") {
      await supabaseClient.rpc("confirm_escrow_deposit", {
        p_gateway_ref: targetGatewayRef,
        p_paid_amount: amount,
        p_gateway_status: mpStatus,
        p_metadata: {
          contract_id: contractIdFromMeta,
          check_status_trigger: true,
          checked_at: new Date().toISOString(),
          payment_type: mpData.payment_type_id,
          payment_method_id: mpData.payment_method_id,
        },
      });
    } else {
      await supabaseClient
        .from("transactions")
        .update({
          status: transactionStatus,
          gateway_status: mpStatus,
          metadata: {
            status_detail: mpData.status_detail,
            last_checked: new Date().toISOString(),
          },
          updated_at: new Date().toISOString(),
        })
        .eq("gateway_ref", targetGatewayRef);
    }

    return new Response(JSON.stringify({
      success: true,
      gateway_ref: targetGatewayRef,
      status: transactionStatus,
      gateway_status: mpStatus,
      status_detail: mpData.status_detail,
      amount: amount,
      is_paid: mpStatus === "approved",
      date_approved: mpData.date_approved,
    }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err: any) {
    console.error("[Check Payment Status Error]:", err);
    const errMsg = err instanceof Error ? err.message : String(err?.message || err);
    return new Response(JSON.stringify({ error: errMsg }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
