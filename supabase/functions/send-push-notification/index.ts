import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-idempotency-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface PushRequestPayload {
  user_id?: string;
  user_ids?: string[];
  tokens?: string[];
  title: string;
  body: string;
  type?: string;
  entity_id?: string;
  route?: string;
  data?: Record<string, string>;
  idempotency_key?: string;
}

// In-memory idempotency cache (TTL: 5 minutes) to prevent duplicate push dispatches
const processedIdempotencyKeys = new Map<string, { timestamp: number; result: any }>();

function isKeyProcessed(key: string): any | null {
  const now = Date.now();
  const cached = processedIdempotencyKeys.get(key);
  if (cached) {
    if (now - cached.timestamp < 5 * 60 * 1000) {
      return cached.result;
    }
    processedIdempotencyKeys.delete(key);
  }
  return null;
}

function recordIdempotencyKey(key: string, result: any): void {
  // Purge old keys if map exceeds 1000 items
  if (processedIdempotencyKeys.size > 1000) {
    const now = Date.now();
    for (const [k, v] of processedIdempotencyKeys.entries()) {
      if (now - v.timestamp > 5 * 60 * 1000) {
        processedIdempotencyKeys.delete(k);
      }
    }
  }
  processedIdempotencyKeys.set(key, { timestamp: Date.now(), result });
}

// Helpers for Google OAuth2 JWT Token generation via Web Crypto (RS256)
function base64UrlEncode(data: Uint8Array | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  let binary = "";
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function pemToArrayBuffer(pem: string): Uint8Array {
  const cleanPem = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/[\r\n\s]/g, "");
  const binary = atob(cleanPem);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

let cachedAccessToken: { token: string; expiresAt: number } | null = null;

async function getGoogleAccessToken(serviceAccount: {
  client_email: string;
  private_key: string;
  project_id: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && cachedAccessToken.expiresAt > now + 60) {
    return cachedAccessToken.token;
  }

  const header = { alg: "RS256", typ: "JWT" };
  const claimSet = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedClaimSet = base64UrlEncode(JSON.stringify(claimSet));
  const unsignedToken = `${encodedHeader}.${encodedClaimSet}`;

  // Sign with Web Crypto API
  const keyData = pemToArrayBuffer(serviceAccount.private_key);
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedToken)
  );

  const signedJwt = `${unsignedToken}.${base64UrlEncode(new Uint8Array(signature))}`;

  // Exchange JWT for OAuth2 Access Token with 5s timeout
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 5000);

  try {
    const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: signedJwt,
      }),
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    if (!tokenRes.ok) {
      const errText = await tokenRes.text();
      throw new Error(`Google OAuth2 token exchange failed (${tokenRes.status}): ${errText}`);
    }

    const tokenData = await tokenRes.json();
    cachedAccessToken = {
      token: tokenData.access_token,
      expiresAt: now + (tokenData.expires_in || 3600),
    };
    return cachedAccessToken.token;
  } catch (err: any) {
    clearTimeout(timeoutId);
    throw err;
  }
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startTime = Date.now();
  let payload: PushRequestPayload;

  try {
    payload = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // 1. Idempotency Check
  const idempotencyKey =
    req.headers.get("x-idempotency-key") || payload.idempotency_key;
  if (idempotencyKey) {
    const previousResult = isKeyProcessed(idempotencyKey);
    if (previousResult) {
      console.log(
        JSON.stringify({
          level: "info",
          event: "idempotent_push_skipped",
          idempotency_key: idempotencyKey,
        })
      );
      return new Response(JSON.stringify({ ...previousResult, idempotent: true }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  // 2. Resolve Target Device Tokens
  let targetTokens: string[] = [];

  if (payload.tokens && payload.tokens.length > 0) {
    targetTokens = payload.tokens;
  } else {
    const targetUserIds = payload.user_ids ?? (payload.user_id ? [payload.user_id] : []);
    if (targetUserIds.length > 0) {
      const { data: dbTokens, error: tokenError } = await supabase
        .from("user_push_tokens")
        .select("token")
        .in("user_id", targetUserIds);

      if (tokenError) {
        console.error(
          JSON.stringify({
            level: "error",
            event: "db_token_fetch_error",
            error: tokenError.message,
          })
        );
      } else if (dbTokens) {
        targetTokens = dbTokens.map((t: { token: string }) => t.token);
      }
    }
  }

  if (targetTokens.length === 0) {
    const emptyResult = {
      success: true,
      message: "No active push tokens registered for recipient",
      sentCount: 0,
      failedCount: 0,
    };
    if (idempotencyKey) recordIdempotencyKey(idempotencyKey, emptyResult);
    return new Response(JSON.stringify(emptyResult), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // 3. Check Firebase Service Account Credentials
  const rawServiceAccount = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (!rawServiceAccount) {
    console.warn(
      JSON.stringify({
        level: "warn",
        event: "fcm_credentials_missing",
        message: "FIREBASE_SERVICE_ACCOUNT secret not configured. Simulating dispatch in dev mode.",
        target_tokens_count: targetTokens.length,
      })
    );
    const mockResult = {
      success: true,
      mode: "development_mock",
      message: "FCM service account not configured. Notification recorded in-app successfully.",
      sentCount: targetTokens.length,
      failedCount: 0,
    };
    if (idempotencyKey) recordIdempotencyKey(idempotencyKey, mockResult);
    return new Response(JSON.stringify(mockResult), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  let serviceAccount: any;
  try {
    serviceAccount = JSON.parse(rawServiceAccount);
  } catch (err: any) {
    console.error(
      JSON.stringify({
        level: "error",
        event: "fcm_service_account_parse_error",
        error: err.message,
      })
    );
    return new Response(
      JSON.stringify({ error: "Malformed FIREBASE_SERVICE_ACCOUNT environment variable" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const projectId = serviceAccount.project_id || "trabalhei-efecb";
  let accessToken: string;
  try {
    accessToken = await getGoogleAccessToken(serviceAccount);
  } catch (authErr: any) {
    console.error(
      JSON.stringify({
        level: "error",
        event: "fcm_auth_error",
        error: authErr.message,
      })
    );
    return new Response(
      JSON.stringify({ error: "Failed to authenticate with Firebase Cloud Messaging" }),
      { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // 4. Dispatch FCM HTTP v1 Messages Concurrently
  // Safe minimal payload (NO sensitive data)
  const safeData: Record<string, string> = {
    type: payload.type || "system",
    entity_id: payload.entity_id || "",
    route: payload.route || "",
    ...(payload.data || {}),
  };

  let sentCount = 0;
  let failedCount = 0;
  const invalidTokensToRemove: string[] = [];

  await Promise.allSettled(
    targetTokens.map(async (token) => {
      const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
      const fcmMessage = {
        message: {
          token: token,
          notification: {
            title: payload.title,
            body: payload.body,
          },
          data: safeData,
          android: {
            priority: "high",
            notification: {
              channel_id: "trabalhei_notifications_channel",
              sound: "default",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
          webpush: {
            notification: {
              icon: "/icons/icon-192.png",
              badge: "/icons/badge-72.png",
            },
          },
        },
      };

      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 6000);

      try {
        const response = await fetch(fcmUrl, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(fcmMessage),
          signal: controller.signal,
        });

        clearTimeout(timeoutId);

        if (response.ok) {
          sentCount++;
        } else {
          failedCount++;
          const errorJson = await response.json().catch(() => ({}));
          const errorCode = errorJson?.error?.details?.[0]?.errorCode || errorJson?.error?.status;

          // Selective cleanup: ONLY remove tokens on PERMANENT unregistration errors
          if (
            errorCode === "UNREGISTERED" ||
            response.status === 404 ||
            errorCode === "INVALID_ARGUMENT"
          ) {
            invalidTokensToRemove.push(token);
          }
        }
      } catch (fcmErr: any) {
        clearTimeout(timeoutId);
        failedCount++;
        // Temporary network/timeout failures DO NOT delete tokens
      }
    })
  );

  // 5. Asynchronous Cleanup of Permanently Invalid Tokens
  if (invalidTokensToRemove.length > 0) {
    try {
      await supabase
        .from("user_push_tokens")
        .delete()
        .in("token", invalidTokensToRemove);

      console.log(
        JSON.stringify({
          level: "info",
          event: "stale_tokens_purged",
          count: invalidTokensToRemove.length,
        })
      );
    } catch (cleanErr: any) {
      console.error(
        JSON.stringify({
          level: "error",
          event: "token_cleanup_failed",
          error: cleanErr.message,
        })
      );
    }
  }

  const durationMs = Date.now() - startTime;
  const finalResult = {
    success: true,
    sentCount,
    failedCount,
    cleanedTokens: invalidTokensToRemove.length,
    durationMs,
  };

  if (idempotencyKey) {
    recordIdempotencyKey(idempotencyKey, finalResult);
  }

  console.log(
    JSON.stringify({
      level: "info",
      event: "push_dispatch_completed",
      sent: sentCount,
      failed: failedCount,
      cleaned: invalidTokensToRemove.length,
      duration_ms: durationMs,
    })
  );

  return new Response(JSON.stringify(finalResult), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
