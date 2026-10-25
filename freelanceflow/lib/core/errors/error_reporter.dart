import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Registra um erro que o usuário viu como mensagem genérica, para a equipe
/// descobrir o que houve: console em desenvolvimento e Sentry em produção
/// (sem SENTRY_DSN, nada é enviado). Cada erro é enviado uma vez só, mesmo
/// que a tela que o mostra seja reconstruída.
void reportError(Object error, [StackTrace? stackTrace, String? context]) {
  if (_alreadyReported(error)) return;
  debugPrint('🚨 [${context ?? 'erro'}] $error${stackTrace != null ? '\n$stackTrace' : ''}');
  if (Sentry.isEnabled) {
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: context == null ? null : (scope) => scope.setTag('contexto', context),
    );
  }
}

final Expando<bool> _reported = Expando('erros-reportados');

bool _alreadyReported(Object error) {
  try {
    if (_reported[error] == true) return true;
    _reported[error] = true;
  } catch (_) {
    // Strings e números não aceitam Expando; seguem sem deduplicação.
  }
  return false;
}
