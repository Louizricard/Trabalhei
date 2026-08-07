import 'package:flutter_test/flutter_test.dart';
import 'package:freelanceflow/features/notifications/domain/entities/app_notification.dart';
import 'package:freelanceflow/features/notifications/domain/repositories/notification_repository.dart';
import 'package:freelanceflow/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:freelanceflow/features/notifications/data/datasources/notification_remote_data_source.dart';
import 'package:freelanceflow/features/notifications/presentation/providers/notification_provider.dart';

class MockNotificationRemoteDataSource implements NotificationRemoteDataSource {
  final List<AppNotification> notifications = [];
  int unreadCount = 0;

  @override
  Future<List<AppNotification>> getNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    return notifications;
  }

  @override
  Stream<List<AppNotification>> streamNotifications() {
    return Stream.value(notifications);
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    final index = notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      notifications[index] = notifications[index].copyWith(isRead: true);
    }
  }

  @override
  Future<int> markAllAsRead() async {
    int updated = 0;
    for (int i = 0; i < notifications.length; i++) {
      if (!notifications[i].isRead) {
        notifications[i] = notifications[i].copyWith(isRead: true);
        updated++;
      }
    }
    return updated;
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    notifications.removeWhere((n) => n.id == notificationId);
  }

  @override
  Future<int> getUnreadCount() async {
    return notifications.where((n) => !n.isRead).length;
  }
}

void main() {
  group('AppNotification Entity & Parsing', () {
    test('Correctly parses JSON and derives route properties', () {
      final json = {
        'id': 'notif-123',
        'user_id': 'user-456',
        'title': 'Nova Proposta',
        'body': 'Você recebeu uma proposta para o projeto.',
        'type': 'proposal_received',
        'data': {
          'route': '/jobs/job-789/proposals',
          'job_id': 'job-789',
          'proposal_id': 'prop-101',
        },
        'is_read': false,
        'created_at': '2026-08-06T18:00:00.000Z',
      };

      final notif = AppNotification.fromJson(json);

      expect(notif.id, 'notif-123');
      expect(notif.userId, 'user-456');
      expect(notif.title, 'Nova Proposta');
      expect(notif.body, 'Você recebeu uma proposta para o projeto.');
      expect(notif.type, NotificationType.proposalReceived);
      expect(notif.isRead, false);
      expect(notif.targetRoute, '/jobs/job-789/proposals');
      expect(notif.jobId, 'job-789');
    });

    test('Serializes back to JSON correctly', () {
      final notif = AppNotification(
        id: 'notif-1',
        userId: 'u1',
        title: 'Mensagem',
        body: 'Olá!',
        type: NotificationType.newMessage,
        data: {'route': '/chat/conv-1', 'conversation_id': 'conv-1'},
        isRead: true,
        createdAt: DateTime.parse('2026-08-06T19:00:00.000Z'),
      );

      final json = notif.toJson();
      expect(json['id'], 'notif-1');
      expect(json['type'], 'new_message');
      expect(json['is_read'], true);
      expect(json['data']['route'], '/chat/conv-1');
    });

    test('Maps all notification types correctly', () {
      expect(
        NotificationType.fromString('new_message'),
        NotificationType.newMessage,
      );
      expect(
        NotificationType.fromString('contract_active'),
        NotificationType.contractActive,
      );
      expect(
        NotificationType.fromString('milestone_submitted'),
        NotificationType.milestoneSubmitted,
      );
      expect(
        NotificationType.fromString('milestone_approved'),
        NotificationType.milestoneApproved,
      );
      expect(NotificationType.fromString('unknown'), NotificationType.system);
    });
  });

  group('NotificationManagerNotifier', () {
    late MockNotificationRemoteDataSource mockDataSource;
    late NotificationRepository repository;
    late NotificationManagerNotifier notifier;

    setUp(() {
      mockDataSource = MockNotificationRemoteDataSource();
      mockDataSource.notifications.addAll([
        AppNotification(
          id: 'n1',
          userId: 'u1',
          title: 'Notif 1',
          body: 'Body 1',
          type: NotificationType.newMessage,
          isRead: false,
          createdAt: DateTime.now(),
        ),
        AppNotification(
          id: 'n2',
          userId: 'u1',
          title: 'Notif 2',
          body: 'Body 2',
          type: NotificationType.contractActive,
          isRead: false,
          createdAt: DateTime.now(),
        ),
      ]);
      repository = NotificationRepositoryImpl(mockDataSource);
      notifier = NotificationManagerNotifier(repository);
    });

    test('Marks specific notification as read', () async {
      await notifier.markAsRead('n1');
      expect(
        mockDataSource.notifications.firstWhere((n) => n.id == 'n1').isRead,
        isTrue,
      );
      expect(
        mockDataSource.notifications.firstWhere((n) => n.id == 'n2').isRead,
        isFalse,
      );
    });

    test('Marks all notifications as read', () async {
      await notifier.markAllAsRead();
      expect(mockDataSource.notifications.every((n) => n.isRead), isTrue);
    });

    test('Deletes notification', () async {
      await notifier.deleteNotification('n1');
      expect(mockDataSource.notifications.length, 1);
      expect(mockDataSource.notifications.first.id, 'n2');
    });
  });
}
