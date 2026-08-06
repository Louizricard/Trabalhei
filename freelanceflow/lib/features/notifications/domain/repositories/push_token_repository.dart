import '../entities/push_token.dart';

/// Abstract contract for managing FCM push tokens persistence
abstract class PushTokenRepository {
  /// Upserts or updates a user's FCM device token in Supabase
  Future<void> saveToken({
    required String userId,
    required String token,
    required String platform,
  });

  /// Deletes a specific FCM token (e.g. upon user logout)
  Future<void> deleteToken({
    required String token,
  });

  /// Retrieves all registered tokens for a given user
  Future<List<PushToken>> getTokensForUser({
    required String userId,
  });
}
