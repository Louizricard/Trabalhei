import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_client.dart';
import '../../data/datasources/notification_remote_data_source.dart';
import '../../data/datasources/push_token_remote_data_source.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../data/repositories/push_token_repository_impl.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/repositories/push_token_repository.dart';
import '../services/notification_service.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';

// ============================================================================
// PUSH TOKEN PROVIDERS
// ============================================================================

/// Provider for PushTokenRemoteDataSource
final pushTokenDataSourceProvider = Provider<PushTokenRemoteDataSource>((ref) {
  return PushTokenRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
});

/// Provider for PushTokenRepository
final pushTokenRepositoryProvider = Provider<PushTokenRepository>((ref) {
  return PushTokenRepositoryImpl(ref.watch(pushTokenDataSourceProvider));
});

/// Provider for NotificationService singleton
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// State of the push notification manager (holds active FCM token)
class PushNotificationState {
  final String? fcmToken;
  final bool isPermissionGranted;
  final bool isSyncing;

  const PushNotificationState({
    this.fcmToken,
    this.isPermissionGranted = false,
    this.isSyncing = false,
  });

  PushNotificationState copyWith({
    String? fcmToken,
    bool? isPermissionGranted,
    bool? isSyncing,
  }) {
    return PushNotificationState(
      fcmToken: fcmToken ?? this.fcmToken,
      isPermissionGranted: isPermissionGranted ?? this.isPermissionGranted,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}

/// Controller that synchronizes FCM push tokens with Supabase auth lifecycle
class PushNotificationNotifier extends StateNotifier<PushNotificationState> {
  final PushTokenRepository _tokenRepository;
  final NotificationService _notificationService;
  final Ref _ref;

  StreamSubscription<String>? _tokenRefreshSubscription;

  PushNotificationNotifier(
    this._tokenRepository,
    this._notificationService,
    this._ref,
  ) : super(const PushNotificationState()) {
    _init();
  }

  void _init() {
    // 1. Listen to token refresh events from FCM
    _tokenRefreshSubscription = _notificationService.onTokenRefresh.listen(
      _handleTokenRefresh,
      onError: (e) {
        debugPrint('🚨 [PushNotificationNotifier] Token refresh error: $e');
      },
    );

    // 2. Reactively listen to user authentication state
    _ref.listen(authProvider, (previous, next) {
      final prevUser = previous?.value;
      final nextUser = next.value;

      if (nextUser != null && prevUser?.id != nextUser.id) {
        // User logged in or switched account -> Register token
        syncTokenForUser(nextUser.id);
      } else if (nextUser == null && prevUser != null) {
        // User logged out -> Delete token from backend
        removeCurrentToken();
      }
    });

    // 3. If user is already logged in at startup, sync token immediately
    final currentUser = _ref.read(authProvider).value;
    if (currentUser != null) {
      syncTokenForUser(currentUser.id);
    }
  }

  /// Requests permission and syncs current device token with Supabase
  Future<void> syncTokenForUser(String userId) async {
    state = state.copyWith(isSyncing: true);
    try {
      final hasPermission = await _notificationService.requestPermissions();
      state = state.copyWith(isPermissionGranted: hasPermission);

      final token = await _notificationService.getToken();
      if (token != null && token.isNotEmpty) {
        final platform = _notificationService.currentPlatform;
        await _tokenRepository.saveToken(
          userId: userId,
          token: token,
          platform: platform,
        );
        state = state.copyWith(fcmToken: token, isSyncing: false);
        debugPrint('✅ [PushNotificationNotifier] FCM token synced for user $userId ($platform)');
      } else {
        state = state.copyWith(isSyncing: false);
      }
    } catch (e, st) {
      state = state.copyWith(isSyncing: false);
      debugPrint('🚨 [PushNotificationNotifier] Error syncing token: $e\n$st');
    }
  }

  /// Handles automatic token refresh by FCM
  Future<void> _handleTokenRefresh(String newToken) async {
    state = state.copyWith(fcmToken: newToken);
    final currentUser = _ref.read(authProvider).value;
    if (currentUser != null) {
      try {
        final platform = _notificationService.currentPlatform;
        await _tokenRepository.saveToken(
          userId: currentUser.id,
          token: newToken,
          platform: platform,
        );
        debugPrint('🔄 [PushNotificationNotifier] Updated refreshed token for user ${currentUser.id}');
      } catch (e) {
        debugPrint('🚨 [PushNotificationNotifier] Error saving refreshed token: $e');
      }
    }
  }

  /// Removes current device token upon user logout
  Future<void> removeCurrentToken() async {
    final token = state.fcmToken;
    if (token != null && token.isNotEmpty) {
      try {
        await _tokenRepository.deleteToken(token: token);
        debugPrint('🧹 [PushNotificationNotifier] Removed push token on logout');
      } catch (e) {
        debugPrint('🚨 [PushNotificationNotifier] Error removing token on logout: $e');
      } finally {
        state = state.copyWith(fcmToken: null);
      }
    }
  }

  @override
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    super.dispose();
  }
}

/// Main provider for push notifications state and sync lifecycle
final pushNotificationProvider =
    StateNotifierProvider<PushNotificationNotifier, PushNotificationState>((ref) {
  final tokenRepo = ref.watch(pushTokenRepositoryProvider);
  final notifService = ref.watch(notificationServiceProvider);
  return PushNotificationNotifier(tokenRepo, notifService, ref);
});

// ============================================================================
// IN-APP NOTIFICATIONS & REALTIME PROVIDERS
// ============================================================================

/// Provider for NotificationRemoteDataSource
final notificationDataSourceProvider = Provider<NotificationRemoteDataSource>((ref) {
  return NotificationRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
});

/// Provider for NotificationRepository
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(ref.watch(notificationDataSourceProvider));
});

/// Realtime stream provider for all active notifications of current user
final notificationsStreamProvider = StreamProvider.autoDispose<List<AppNotification>>((ref) {
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

  const NotificationManagerState({
    this.isLoading = false,
    this.errorMessage,
  });

  NotificationManagerState copyWith({
    bool? isLoading,
    String? errorMessage,
  }) {
    return NotificationManagerState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// Notifier for notification actions (mark as read, mark all as read, delete)
class NotificationManagerNotifier extends StateNotifier<NotificationManagerState> {
  final NotificationRepository _repository;

  NotificationManagerNotifier(this._repository) : super(const NotificationManagerState());

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
      state = state.copyWith(isLoading: false, errorMessage: 'Erro ao marcar todas como lidas');
      debugPrint('🚨 [NotificationManagerNotifier] Error marking all as read: $e');
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _repository.deleteNotification(id);
    } catch (e) {
      debugPrint('🚨 [NotificationManagerNotifier] Error deleting notification: $e');
    }
  }
}

final notificationManagerProvider =
    StateNotifierProvider<NotificationManagerNotifier, NotificationManagerState>((ref) {
  return NotificationManagerNotifier(ref.watch(notificationRepositoryProvider));
});
