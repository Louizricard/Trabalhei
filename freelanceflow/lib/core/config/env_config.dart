import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized configuration reader for environment variables.
class EnvConfig {
  static Future<void> init() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // Fallback if .env is missing or packaged differently in assets
    }
  }

  static String get supabaseUrl {
    return dotenv.env['SUPABASE_URL'] ??
        const String.fromEnvironment('SUPABASE_URL',
            defaultValue: 'https://wmfsjitjqltzbbgynwfb.supabase.co');
  }

  static String get supabaseAnonKey {
    return dotenv.env['SUPABASE_ANON_KEY'] ??
        const String.fromEnvironment(
          'SUPABASE_ANON_KEY',
          defaultValue:
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndtZnNqaXRqcWx0emJiZ3lud2ZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU1MDY4MTEsImV4cCI6MjEwMTA4MjgxMX0.UtM7W4x3BE_enGmyBzQOdgcm59EX1BNn3PC2LcNxu2Y',
        );
  }

  static String get mercadoPagoPublicKey {
    return dotenv.env['MERCADO_PAGO_PUBLIC_KEY'] ??
        const String.fromEnvironment('MERCADO_PAGO_PUBLIC_KEY',
            defaultValue: 'APP_USR-9e73d8bb-4629-4660-959d-11880b3c4df0');
  }

  static String get mercadoPagoClientId {
    return dotenv.env['MERCADO_PAGO_CLIENT_ID'] ??
        const String.fromEnvironment('MERCADO_PAGO_CLIENT_ID',
            defaultValue: '8031981668422592');
  }
}
