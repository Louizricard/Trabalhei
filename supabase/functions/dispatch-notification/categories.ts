// Categoria de cada tipo de notificação, para as preferências por categoria
// (notification_settings.muted_categories). Espelha NotificationCategory no app.
export type NotificationCategory = "messages" | "proposals" | "contracts" | "updates" | "opportunities";

// Avisos da moderação chegam sempre: nem suspensão nem preferência os calam.
export const MODERATION_TYPES = new Set(["account_suspended", "account_restored"]);

export function categoryOf(type: string): NotificationCategory {
  if (type === "new_message") return "messages";
  if (type.startsWith("proposal_")) return "proposals";
  if (type.startsWith("contract_") || type.startsWith("milestone_")) return "contracts";
  if (type === "job_alert") return "opportunities";
  return "updates";
}

/** E-mail e push dessa notificação estão silenciados pela pessoa? */
export function isMuted(type: string, muted: readonly string[] | null | undefined): boolean {
  if (MODERATION_TYPES.has(type)) return false;
  return (muted ?? []).includes(categoryOf(type));
}
