import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/platform/browser_session.dart';
import 'providers/auth_state_provider.dart';
import 'providers/password_recovery_provider.dart';
import 'providers/pending_confirmation_provider.dart';

/// Link de confirmação de cadastro ou de redefinição de senha enviado por
/// e-mail: `/app/?token_hash=...&type=email|recovery`. Funciona em qualquer
/// navegador, inclusive diferente do que pediu o e-mail.
class EmailLink {
  final String tokenHash;
  final bool recovery;

  const EmailLink._(this.tokenHash, this.recovery);

  static EmailLink? fromUri(Uri uri) {
    final tokenHash = uri.queryParameters['token_hash'];
    if (tokenHash == null || tokenHash.isEmpty) return null;
    return EmailLink._(tokenHash, uri.queryParameters['type'] == 'recovery');
  }

  /// Valida o link e devolve a rota de destino.
  Future<String> open(WidgetRef ref) async {
    try {
      await ref
          .read(authProvider.notifier)
          .verifyEmailLink(tokenHash: tokenHash, recovery: recovery);
      if (recovery) {
        ref.read(passwordRecoveryProvider.notifier).state = true;
        return '/reset-password';
      }
      await ref.read(pendingConfirmationProvider.notifier).clear();
      return '/jobs';
    } catch (_) {
      // Link expirado ou já usado: o usuário pede outro pela tela de login.
      final notice = recovery
          ? 'Este link de redefinição expirou ou já foi usado. Peça um novo em "Esqueceu a senha?".'
          : 'Este link de confirmação expirou ou já foi usado. Entre com sua senha ou peça um novo link.';
      return '/login?notice=${Uri.encodeComponent(notice)}';
    } finally {
      // Recarregar a página não deve tentar usar o mesmo link de novo.
      clearUrlQuery();
    }
  }
}
