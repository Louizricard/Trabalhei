import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'web_push.dart';

/// API de `web/push.js` (window.trabalheiPush).
JSObject? get _api => globalContext['trabalheiPush'] as JSObject?;

bool get webPushSupported =>
    _api?.callMethod<JSBoolean>('supported'.toJS).toDart ?? false;

/// `granted`, `denied`, `default` ou `unsupported`.
String get webPushPermission =>
    _api?.callMethod<JSString>('permission'.toJS).toDart ?? 'unsupported';

/// Pede permissão e inscreve o navegador; `null` se a pessoa negar.
Future<WebPushSubscription?> subscribeWebPush(String vapidPublicKey) async {
  final api = _api;
  if (api == null) return null;
  final result = await api
      .callMethod<JSPromise<JSString?>>('subscribe'.toJS, vapidPublicKey.toJS)
      .toDart;
  if (result == null) return null;
  return WebPushSubscription.fromJson(
    Map<String, dynamic>.from(jsonDecode(result.toDart) as Map),
  );
}

Future<String?> currentWebPushEndpoint() async {
  final api = _api;
  if (api == null) return null;
  final result = await api
      .callMethod<JSPromise<JSString?>>('endpoint'.toJS)
      .toDart;
  return result?.toDart;
}

/// Cancela a inscrição deste navegador e devolve o endpoint removido.
Future<String?> unsubscribeWebPush() async {
  final api = _api;
  if (api == null) return null;
  final result = await api
      .callMethod<JSPromise<JSString?>>('unsubscribe'.toJS)
      .toDart;
  return result?.toDart;
}
