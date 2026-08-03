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
}
