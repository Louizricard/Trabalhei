import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Assina um stream Realtime do Supabase com recuperação.
///
/// Quando o app volta do segundo plano, o token pode estar vencido e a assinatura
/// falha com `InvalidJWTToken`. Antes de cada tentativa a sessão é renovada se
/// estiver expirada; o erro só chega à tela depois de [maxAttempts] falhas seguidas.
Stream<T> resilientRealtimeStream<T>(
  SupabaseClient supabase,
  Stream<T> Function() subscribe, {
  int maxAttempts = 3,
}) async* {
  var failures = 0;
  while (true) {
    try {
      await _refreshExpiredSession(supabase);
      await for (final event in subscribe()) {
        failures = 0;
        yield event;
      }
      return;
    } catch (_) {
      failures++;
      if (failures >= maxAttempts) rethrow;
      await Future<void>.delayed(Duration(seconds: failures));
    }
  }
}

Future<void> _refreshExpiredSession(SupabaseClient supabase) async {
  final session = supabase.auth.currentSession;
  if (session == null || !session.isExpired) return;
  try {
    await supabase.auth.refreshSession();
  } catch (_) {
    // Sem rede ou refresh token inválido: a assinatura falha e entra no retry.
  }
}
