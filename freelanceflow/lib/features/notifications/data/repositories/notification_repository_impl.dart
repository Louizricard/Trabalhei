import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_remote_data_source.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource _remoteDataSource;

  NotificationRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<AppNotification>> getNotifications({int limit = 50, int offset = 0}) {
    return _remoteDataSource.getNotifications(limit: limit, offset: offset);
  }

  @override
  Stream<List<AppNotification>> streamNotifications() {
    return _remoteDataSource.streamNotifications();
  }

  @override
  Future<void> markAsRead(String notificationId) {
    return _remoteDataSource.markAsRead(notificationId);
  }

  @override
  Future<int> markAllAsRead() {
    return _remoteDataSource.markAllAsRead();
  }

  @override
  Future<void> deleteNotification(String notificationId) {
    return _remoteDataSource.deleteNotification(notificationId);
  }

  @override
  Future<int> getUnreadCount() {
    return _remoteDataSource.getUnreadCount();
  }
}
