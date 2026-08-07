import '../entities/app_notification.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> getNotifications({
    int limit = 50,
    int offset = 0,
  });
  Stream<List<AppNotification>> streamNotifications();
  Future<void> markAsRead(String notificationId);
  Future<int> markAllAsRead();
  Future<void> deleteNotification(String notificationId);
  Future<int> getUnreadCount();
}
