// Entrega uma notificação por e-mail (Resend) e por push (Web Push).
// Chamada pelo banco (trigger notifications_dispatch, via pg_net) com { id }.
// Cada notificação é entregue uma vez só e apenas se for recente, então chamar
// de novo com o mesmo id não repete o envio. Chaves vêm do Vault
// (função notification_secrets, só para o service_role).
import { adminClient, handle, HttpError, json, reportError } from "../_shared/common.ts";
import { sendPush } from "./webpush.ts";

const FRESH_MINUTES = 15;
const FROM = "Trabalhei <notificacoes@trabalhei.site>";
// Avisos da moderação chegam mesmo com a conta suspensa.
const MODERATION_TYPES = new Set(["account_suspended", "account_restored"]);

interface Notification {
  id: string;
  user_id: string;
  type: string;
  title: string;
  body: string;
  data: { route?: string } | null;
}

const escapeHtml = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

function emailHtml(n: Notification, link: string, name: string): string {
  return `<!doctype html>
<html lang="pt-BR">
  <body style="margin:0;padding:24px;background:#f4f6f8;font-family:Arial,Helvetica,sans-serif;color:#0f172a;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;margin:0 auto;background:#ffffff;border-radius:12px;">
      <tr><td style="padding:28px 28px 8px;font-size:20px;font-weight:bold;color:#081a2f;">Trabalhei</td></tr>
      <tr>
        <td style="padding:8px 28px 28px;font-size:15px;line-height:1.6;">
          <p style="margin:0 0 4px;">Olá${name ? `, ${escapeHtml(name)}` : ""}!</p>
          <p style="margin:0;font-weight:bold;">${escapeHtml(n.title)}</p>
          ${n.body ? `<p style="margin:8px 0 0;color:#334155;">${escapeHtml(n.body)}</p>` : ""}
          <p style="margin:24px 0 0;">
            <a href="${link}" style="background:#19e6a7;color:#081a2f;padding:12px 20px;border-radius:8px;text-decoration:none;font-weight:bold;display:inline-block;">Abrir no Trabalhei</a>
          </p>
        </td>
      </tr>
    </table>
    <p style="max-width:480px;margin:16px auto 0;font-size:12px;color:#64748b;text-align:center;">
      Para parar de receber estes e-mails, desative em Perfil &gt; Notificações no app.
    </p>
  </body>
</html>`;
}

Deno.serve(handle(async (req) => {
  const { id } = await req.json().catch(() => ({}));
  if (typeof id !== "string") throw new HttpError(400, "id é obrigatório.");

  const admin = adminClient();
  // Marca como entregue antes de enviar: chamadas repetidas não acham mais nada.
  const since = new Date(Date.now() - FRESH_MINUTES * 60_000).toISOString();
  const { data: n } = await admin
    .from("notifications")
    .update({ delivered_at: new Date().toISOString() })
    .eq("id", id)
    .is("delivered_at", null)
    .gt("created_at", since)
    .select("id, user_id, type, title, body, data")
    .maybeSingle<Notification>();
  if (!n) return json({ skipped: true });

  const [profileRes, settingsRes, secretsRes, userRes] = await Promise.all([
    admin.from("profiles").select("full_name, deleted_at, suspended_at").eq("id", n.user_id).maybeSingle(),
    admin.from("notification_settings").select("email_enabled, push_enabled").eq("user_id", n.user_id).maybeSingle(),
    admin.rpc("notification_secrets"),
    admin.auth.admin.getUserById(n.user_id),
  ]);
  const profile = profileRes.data;
  if (!profile || profile.deleted_at) return json({ skipped: true });
  if (profile.suspended_at && !MODERATION_TYPES.has(n.type)) return json({ skipped: true });

  const settings = settingsRes.data ?? { email_enabled: true, push_enabled: true };
  const secrets = (secretsRes.data ?? {}) as Record<string, string>;
  const appUrl = (secrets.app_url ?? "").replace(/\/$/, "");
  const route = n.data?.route ?? "/notifications";
  const link = `${appUrl}/#${route}`;
  const firstName = String(profile.full_name ?? "").trim().split(/\s+/)[0] ?? "";
  // O motivo de não enviar fica na resposta (visível em net._http_response).
  const result: Record<string, unknown> = { email: false, push: 0 };

  const email = userRes.data?.user?.email;
  if (!settings.email_enabled) result.email_skipped = "desativado";
  else if (!email) result.email_skipped = userRes.error ? `sem e-mail: ${userRes.error.message}` : "sem e-mail";
  else if (!secrets.resend_api_key) result.email_skipped = secretsRes.error ? `sem chave: ${secretsRes.error.message}` : "sem chave";
  else {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${secrets.resend_api_key}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        from: FROM,
        to: [email],
        subject: n.title,
        html: emailHtml(n, link, firstName),
        text: `${n.title}\n\n${n.body}\n\nAbrir no Trabalhei: ${link}`,
      }),
    });
    result.email = res.ok;
    if (!res.ok) await reportError("dispatch-notification", new Error(`Resend ${res.status}: ${await res.text()}`));
  }

  if (settings.push_enabled && secrets.vapid_public_key && secrets.vapid_private_key) {
    const { data: subs } = await admin
      .from("push_subscriptions")
      .select("id, endpoint, p256dh, auth")
      .eq("user_id", n.user_id);
    const vapid = {
      publicKey: secrets.vapid_public_key,
      privateKey: secrets.vapid_private_key,
      subject: "mailto:notificacoes@trabalhei.site",
    };
    for (const sub of subs ?? []) {
      try {
        const status = await sendPush(sub, { title: n.title, body: n.body, route }, vapid);
        if (status === 404 || status === 410) {
          await admin.from("push_subscriptions").delete().eq("id", sub.id);
        } else if (status < 300) {
          result.push = Number(result.push) + 1;
        } else {
          await reportError("dispatch-notification", new Error(`Push ${status}`), { endpoint: new URL(sub.endpoint).host });
        }
      } catch (e) {
        await reportError("dispatch-notification", e, { endpoint: new URL(sub.endpoint).host });
      }
    }
  }

  return json(result);
}));
