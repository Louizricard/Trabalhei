import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/backend_errors.dart';
import '../../../core/platform/web_push.dart';

/// Como a pessoa quer receber os avisos, além do sino do app.
class NotificationPreferences {
  final bool emailEnabled;
  final bool pushEnabled;

  const NotificationPreferences({
    this.emailEnabled = true,
    this.pushEnabled = true,
  });
}

/// Preferências de e-mail/push e inscrições de Web Push deste navegador.
class NotificationPreferencesRepository {
  final SupabaseClient _supabase;

  NotificationPreferencesRepository(this._supabase);

  Future<NotificationPreferences> load() async {
    final row = await _supabase
        .from('notification_settings')
        .select('email_enabled, push_enabled')
        .maybeSingle();
    if (row == null) return const NotificationPreferences();
    return NotificationPreferences(
      emailEnabled: row['email_enabled'] as bool? ?? true,
      pushEnabled: row['push_enabled'] as bool? ?? true,
    );
  }

  Future<void> setEmailEnabled(bool enabled) async {
    await _supabase.from('notification_settings').upsert({
      'user_id': _supabase.auth.currentUser!.id,
      'email_enabled': enabled,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Ativa o push neste navegador (pede permissão). `false` se negado.
  Future<bool> enablePushHere() async {
    final key = await _supabase.rpc('push_public_key') as String?;
    if (key == null || key.isEmpty) {
      throw const AppMessageException(
        'As notificações push ainda não estão disponíveis. Tente mais tarde.',
      );
    }
    final sub = await subscribeWebPush(key);
    if (sub == null) return false;
    // Uma inscrição antiga deste navegador (de outra conta) é trocada por esta.
    await _supabase
        .from('push_subscriptions')
        .delete()
        .eq('endpoint', sub.endpoint);
    await _supabase.from('push_subscriptions').insert({
      'endpoint': sub.endpoint,
      'p256dh': sub.p256dh,
      'auth': sub.auth,
    });
    await _supabase.from('notification_settings').upsert({
      'user_id': _supabase.auth.currentUser!.id,
      'push_enabled': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    return true;
  }

  /// Desativa o push neste navegador. Chamado também ao sair da conta.
  Future<void> disablePushHere() async {
    final endpoint = await unsubscribeWebPush();
    if (endpoint != null && _supabase.auth.currentUser != null) {
      await _supabase
          .from('push_subscriptions')
          .delete()
          .eq('endpoint', endpoint);
    }
  }

  /// Este navegador está inscrito e com o endpoint salvo na conta?
  Future<bool> isPushActiveHere() async {
    final endpoint = await currentWebPushEndpoint();
    if (endpoint == null || webPushPermission != 'granted') return false;
    final row = await _supabase
        .from('push_subscriptions')
        .select('id')
        .eq('endpoint', endpoint)
        .maybeSingle();
    return row != null;
  }
}
