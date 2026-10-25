import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/platform/browser_session.dart';

/// "Manter conectado": quando desmarcado, a sessão vale só até fechar o app
/// (ou a aba, na Web). Na próxima abertura o login é pedido de novo.
class SessionPolicy {
  SessionPolicy._();

  static const _key = 'manter_conectado';

  static Future<bool> keepSignedIn() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_key) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Chamado após um login bem-sucedido.
  static Future<void> remember({required bool keepSignedIn}) async {
    markBrowserSession();
    try {
      await (await SharedPreferences.getInstance()).setBool(_key, keepSignedIn);
    } catch (_) {
      // Sem armazenamento local: segue com o padrão (manter conectado).
    }
  }

  /// Na abertura do app: encerra a sessão anterior de quem não quis ficar
  /// conectado. Recarregar a mesma aba não conta como abrir de novo.
  static Future<void> enforceOnStartup(GoTrueClient auth) async {
    if (auth.currentSession == null || isBrowserSessionMarked()) return;
    if (await keepSignedIn()) return;
    await auth.signOut(scope: SignOutScope.local);
  }
}
