import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/features/notifications/data/notification_preferences_repository.dart';
import 'package:trabalhei/features/notifications/domain/entities/app_notification.dart';
import 'package:trabalhei/features/notifications/domain/entities/notification_category.dart';

void main() {
  group('NotificationCategory.of', () {
    test('cada tipo cai na categoria certa', () {
      expect(
        NotificationCategory.of(NotificationType.newMessage),
        NotificationCategory.messages,
      );
      expect(
        NotificationCategory.of(NotificationType.proposalAccepted),
        NotificationCategory.proposals,
      );
      expect(
        NotificationCategory.of(NotificationType.milestoneInRevision),
        NotificationCategory.contracts,
      );
      expect(
        NotificationCategory.of(NotificationType.jobAlert),
        NotificationCategory.opportunities,
      );
      expect(
        NotificationCategory.of(NotificationType.system),
        NotificationCategory.updates,
      );
    });

    test('chaves batem com as aceitas pelo banco', () {
      expect(NotificationCategory.values.map((c) => c.key), [
        'messages',
        'proposals',
        'contracts',
        'updates',
        'opportunities',
      ]);
    });
  });

  group('NotificationPreferences', () {
    test('sem linha: tudo ligado', () {
      final p = NotificationPreferences.fromRow(null);
      expect(p.emailEnabled, isTrue);
      expect(NotificationCategory.values.every(p.isEnabled), isTrue);
    });

    test('lê categorias silenciadas e ignora chave desconhecida', () {
      final p = NotificationPreferences.fromRow({
        'email_enabled': false,
        'push_enabled': true,
        'muted_categories': ['messages', 'antiga'],
      });
      expect(p.emailEnabled, isFalse);
      expect(p.isEnabled(NotificationCategory.messages), isFalse);
      expect(p.isEnabled(NotificationCategory.proposals), isTrue);
    });

    test('liga e desliga sem perder as outras categorias', () {
      final p = NotificationPreferences.fromRow({
        'muted_categories': ['updates'],
      });
      expect(p.mutedKeysWith(NotificationCategory.messages, false), [
        'messages',
        'updates',
      ]);
      expect(p.mutedKeysWith(NotificationCategory.updates, true), isEmpty);
    });
  });
}
