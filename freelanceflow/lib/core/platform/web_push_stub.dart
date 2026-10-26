import 'web_push.dart';

bool get webPushSupported => false;

/// `granted`, `denied`, `default` ou `unsupported`.
String get webPushPermission => 'unsupported';

Future<WebPushSubscription?> subscribeWebPush(String vapidPublicKey) async =>
    null;

Future<String?> currentWebPushEndpoint() async => null;

Future<String?> unsubscribeWebPush() async => null;
