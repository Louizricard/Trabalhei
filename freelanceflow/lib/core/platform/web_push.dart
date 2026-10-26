/// Notificações push do navegador (Web Push). Fora da Web, nada é suportado.
library;

export 'web_push_stub.dart' if (dart.library.js_interop) 'web_push_web.dart';

/// Inscrição do navegador, enviada ao servidor para receber os pushes.
class WebPushSubscription {
  final String endpoint;
  final String p256dh;
  final String auth;

  const WebPushSubscription({
    required this.endpoint,
    required this.p256dh,
    required this.auth,
  });

  /// A partir de `PushSubscription.toJSON()` do navegador.
  factory WebPushSubscription.fromJson(Map<String, dynamic> json) {
    final keys = Map<String, dynamic>.from(json['keys'] as Map);
    return WebPushSubscription(
      endpoint: json['endpoint'] as String,
      p256dh: keys['p256dh'] as String,
      auth: keys['auth'] as String,
    );
  }
}
