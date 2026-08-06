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

    if (!supabaseServiceKey) {
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
      return new Response(JSON.stringify({ error: "Sessão inválida ou expirada" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { amount, pix_key, pix_key_type } = await req.json();

    if (!amount || amount <= 0) {
      return new Response(JSON.stringify({ error: "Valor de saque inválido" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!pix_key || !pix_key.trim()) {
      return new Response(JSON.stringify({ error: "Chave Pix é obrigatória" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 1. Executar a Stored Procedure atômica com lock para debitar o saldo
    const { data: payoutRpc, error: rpcError } = await supabaseClient.rpc("request_pix_payout", {
      p_amount: amount,
      p_pix_key: pix_key.trim(),
    });

    if (rpcError) {
      console.error("Erro no RPC request_pix_payout:", rpcError);
      return new Response(JSON.stringify({ error: rpcError.message || "Saldo insuficiente ou erro ao processar saque." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const transactionId = payoutRpc?.transaction_id;
    const gatewayRef = `payout_mp_${Date.now()}_${user.id.substring(0, 6)}`;

    // 2. Registrar referência e dados do gateway na transação
    if (transactionId) {
      await supabaseClient
        .from("transactions")
        .update({
          gateway_provider: "mercadopago",
          gateway_ref: gatewayRef,
          gateway_status: "in_process",
          metadata: {
            pix_key: pix_key.trim(),
            pix_key_type: pix_key_type || "auto",
            requested_at: new Date().toISOString(),
          },
          updated_at: new Date().toISOString(),
        })
        .eq("id", transactionId);
    }

    if (mpAccessToken) {
      console.log(`[Payout MP] Saque de R$ ${amount} registrado para chave ${pix_key}`);
    }

    return new Response(JSON.stringify({
      success: true,
      transaction_id: transactionId,
      gateway_ref: gatewayRef,
      status: "in_process",
      amount: amount,
      message: "Saque Pix solicitado com sucesso.",
    }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err: any) {
    console.error("[Payout Exception]:", err);
    const errMsg = err instanceof Error ? err.message : String(err?.message || err);
    return new Response(JSON.stringify({ error: errMsg }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
