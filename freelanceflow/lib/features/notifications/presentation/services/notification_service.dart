import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level background message handler required by Firebase Cloud Messaging
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('🚨 [FCM Background] Firebase initialization error: $e');
  }
  debugPrint('📬 [FCM Background Message] ID: ${message.messageId}, Data: ${message.data}');
}

/// Centralized service handling Firebase Cloud Messaging and Local Notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService({
    FirebaseMessaging? fcm,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) {
    if (fcm != null) _instance._fcmInstance = fcm;
    if (localNotifications != null) {
      _instance._localNotificationsInstance = localNotifications;
    }
    return _instance;
  }
  NotificationService._internal();

  bool get isFirebaseAvailable => Firebase.apps.isNotEmpty;
  bool get isFcmSupported =>
      isFirebaseAvailable &&
      (kIsWeb ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  FirebaseMessaging? _fcmInstance;
  FirebaseMessaging? get _fcm {
    if (!isFcmSupported) return null;
    return _fcmInstance ??= FirebaseMessaging.instance;
  }

  FlutterLocalNotificationsPlugin? _localNotificationsInstance;
  FlutterLocalNotificationsPlugin get _localNotifications =>
      _localNotificationsInstance ??= FlutterLocalNotificationsPlugin();

  static const String channelId = 'trabalhei_notifications_channel';
  static const String channelName = 'Notificações Trabalhei';
  static const String channelDescription =
      'Notificações sobre mensagens, propostas, contratos e pagamentos.';

  final _navigationStreamController = StreamController<String>.broadcast();
  Stream<String> get onNotificationNavigation => _navigationStreamController.stream;

  bool _isInitialized = false;

  /// Initializes local notifications, notification channels, and FCM listeners
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Initialize local notifications
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open');

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onLocalNotificationTapped,
      );

      // 2. Create high-importance Android notification channel
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        const androidChannel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(androidChannel);
      }

      // 3. Setup FCM only if supported on current platform
      if (isFcmSupported && _fcm != null) {
        // Set foreground presentation options for iOS/macOS
        await _fcm!.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        // Setup foreground message listener
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Setup background message opened listener
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

        // Check if app was opened from a terminated state via notification
        final initialMessage = await _fcm!.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageOpenedApp(initialMessage);
        }
      }

      _isInitialized = true;
      debugPrint('🔔 [NotificationService] Initialized successfully (FCM supported: $isFcmSupported)');
    } catch (e, st) {
      debugPrint('🚨 [NotificationService] Initialization error: $e\n$st');
    }
  }

  /// Requests push notification permissions from the operating system
  Future<bool> requestPermissions() async {
    try {
      if (!isFcmSupported || _fcm == null) {
        return false;
      }

      final settings = await _fcm!.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }

      final isAuthorized = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      debugPrint('🔔 [NotificationService] Permission status: ${settings.authorizationStatus}');
      return isAuthorized;
    } catch (e) {
      debugPrint('🚨 [NotificationService] Request permission error: $e');
      return false;
    }
  }

  /// Retrieves the device FCM registration token
  Future<String?> getToken() async {
    try {
      if (!isFcmSupported || _fcm == null) {
        return null;
      }
      return await _fcm!.getToken();
    } catch (e) {
      debugPrint('🚨 [NotificationService] Failed to get FCM token: $e');
      return null;
    }
  }

  /// Stream of FCM token refresh events
  Stream<String> get onTokenRefresh =>
      isFcmSupported && _fcm != null ? _fcm!.onTokenRefresh : const Stream.empty();

  /// Returns current platform string for backend storage
  String get currentPlatform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'android';
    }
  }

  /// Displays local notification banner for foreground FCM messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('🔔 [FCM Foreground] Received: ${message.notification?.title} - ${message.notification?.body}');
    debugPrint('🔔 [FCM Foreground Data] ${message.data}');

    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'Nova notificação';
    final body = notification?.body ?? message.data['body'] ?? '';

    final payloadString = jsonEncode(message.data);

    showLocalNotification(
      id: message.messageId.hashCode,
      title: title,
      body: body,
      payload: payloadString,
    );
  }

  /// Displays a heads-up local notification banner
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _localNotifications.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('🚨 [NotificationService] Show local notification error: $e');
    }
  }

  /// Handles notification click when opening app from background or terminated state
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('🚀 [FCM MessageOpenedApp] User tapped notification: ${message.data}');
    final route = extractRouteFromData(message.data);
    if (route != null && route.isNotEmpty) {
      _navigationStreamController.add(route);
    }
  }

  /// Handles local notification tap response
  void _onLocalNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final Map<String, dynamic> data = jsonDecode(payload);
      final route = extractRouteFromData(data);
      if (route != null && route.isNotEmpty) {
        _navigationStreamController.add(route);
      }
    } catch (_) {
      // If payload is a direct route string
      _navigationStreamController.add(payload);
    }
  }

  /// Extracts target GoRouter path from notification data map
  String? extractRouteFromData(Map<String, dynamic> data) {
    if (data.containsKey('route') && data['route'] != null) {
      return data['route'].toString();
    }
    if (data.containsKey('conversation_id') && data['conversation_id'] != null) {
      return '/chat/${data['conversation_id']}';
    }
    if (data.containsKey('job_id') && data['job_id'] != null) {
      if (data['type'] == 'proposal' || data.containsKey('proposal_id')) {
        return '/jobs/${data['job_id']}/proposals';
      }
      return '/jobs/${data['job_id']}';
    }
    if (data.containsKey('type') && data['type'] == 'payments') {
      return '/payments';
    }
    return null;
  }

  void dispose() {
    _navigationStreamController.close();
  }
}
