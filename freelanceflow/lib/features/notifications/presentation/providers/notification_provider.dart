import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_client.dart';
import '../../data/datasources/notification_remote_data_source.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

// ============================================================================
// IN-APP NOTIFICATIONS & REALTIME PROVIDERS
// ============================================================================

/// Provider for NotificationRemoteDataSource
final notificationDataSourceProvider = Provider<NotificationRemoteDataSource>((
  ref,
) {
  return NotificationRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
});

/// Provider for NotificationRepository
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(ref.watch(notificationDataSourceProvider));
});

/// Realtime stream provider for all active notifications of current user
final notificationsStreamProvider =
    StreamProvider.autoDispose<List<AppNotification>>((ref) {
      final repo = ref.watch(notificationRepositoryProvider);
      return repo.streamNotifications();
    });

/// Unread notifications count provider
final unreadNotificationsCountProvider = Provider.autoDispose<int>((ref) {
  final asyncNotifs = ref.watch(notificationsStreamProvider);
  return asyncNotifs.maybeWhen(
    data: (notifs) => notifs.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});

/// State for notifications manager
class NotificationManagerState {
  final bool isLoading;
  final String? errorMessage;

  const NotificationManagerState({this.isLoading = false, this.errorMessage});

  NotificationManagerState copyWith({bool? isLoading, String? errorMessage}) {
    return NotificationManagerState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// Notifier for notification actions (mark as read, mark all as read, delete)
class NotificationManagerNotifier
    extends StateNotifier<NotificationManagerState> {
  final NotificationRepository _repository;

  NotificationManagerNotifier(this._repository)
    : super(const NotificationManagerState());

  Future<void> markAsRead(String id) async {
    try {
      await _repository.markAsRead(id);
    } catch (e) {
      debugPrint('🚨 [NotificationManagerNotifier] Error marking as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.markAllAsRead();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erro ao marcar todas como lidas',
      );
      debugPrint(
        '🚨 [NotificationManagerNotifier] Error marking all as read: $e',
      );
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _repository.deleteNotification(id);
    } catch (e) {
      debugPrint(
        '🚨 [NotificationManagerNotifier] Error deleting notification: $e',
      );
    }
  }
}

final notificationManagerProvider =
    StateNotifierProvider<
      NotificationManagerNotifier,
      NotificationManagerState
    >((ref) {
      return NotificationManagerNotifier(
        ref.watch(notificationRepositoryProvider),
      );
    });
