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
    await EnvConfig.init();
    // ignore: deprecated_member_use
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: EnvConfig.supabaseAnonKey,
      debug: false,
    );
  }
}
