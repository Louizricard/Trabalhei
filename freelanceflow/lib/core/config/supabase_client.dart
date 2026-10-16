import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'env_config.dart';

/// Provider for accessing the initialized SupabaseClient
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Helper to initialize Supabase on app startup
class SupabaseInit {
  static Future<void> initialize() async {
    if (!EnvConfig.isConfigured) {
      throw StateError(
        'SUPABASE_URL e SUPABASE_ANON_KEY não definidos. '
        'Rode com --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
      );
    }
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      publishableKey: EnvConfig.supabaseAnonKey,
    );
  }
}
