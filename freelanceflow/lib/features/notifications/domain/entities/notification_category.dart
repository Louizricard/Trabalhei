import 'app_notification.dart';

/// Grupos de avisos que a pessoa pode silenciar no e-mail e no push.
/// Espelha `categoryOf` em `supabase/functions/dispatch-notification`.
enum NotificationCategory {
  messages('messages', 'Mensagens', 'Novas mensagens nos seus chats'),
  proposals(
    'proposals',
    'Propostas',
    'Propostas recebidas e respostas às suas',
  ),
  contracts(
    'contracts',
    'Contratos',
    'Início, entregas, revisões e aprovações de etapas',
  ),
  updates(
    'updates',
    'Atualizações',
    'Avisos da plataforma, da sua conta e das suas vagas',
  ),
  opportunities(
    'opportunities',
    'Novas oportunidades',
    'Vagas que combinam com os seus alertas',
  );

  final String key;
  final String label;
  final String description;

  const NotificationCategory(this.key, this.label, this.description);

  static NotificationCategory? fromKey(String key) {
    for (final c in values) {
      if (c.key == key) return c;
    }
    return null;
  }

  static NotificationCategory of(NotificationType type) => switch (type) {
    NotificationType.newMessage => messages,
    NotificationType.proposalReceived ||
    NotificationType.proposalAccepted => proposals,
    NotificationType.contractActive ||
    NotificationType.milestoneSubmitted ||
    NotificationType.milestoneInRevision ||
    NotificationType.milestoneApproved => contracts,
    NotificationType.jobAlert => opportunities,
    NotificationType.system => updates,
  };
}
