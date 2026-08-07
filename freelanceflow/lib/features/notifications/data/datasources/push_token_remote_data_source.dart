import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/push_token.dart';

abstract class PushTokenRemoteDataSource {
  Future<void> upsertToken({
    required String userId,
    required String token,
    required String platform,
  });

  Future<void> deleteToken({required String token});

  Future<List<PushToken>> getTokensForUser({required String userId});
}

class PushTokenRemoteDataSourceImpl implements PushTokenRemoteDataSource {
  final SupabaseClient _supabase;

  PushTokenRemoteDataSourceImpl(this._supabase);

  @override
  Future<void> upsertToken({
    required String userId,
    required String token,
    required String platform,
  }) async {
    await _supabase.from('user_push_tokens').upsert({
      'user_id': userId,
      'token': token,
      'platform': platform,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'token');
  }

  @override
  Future<void> deleteToken({required String token}) async {
    await _supabase.from('user_push_tokens').delete().eq('token', token);
  }

  @override
  Future<List<PushToken>> getTokensForUser({required String userId}) async {
    final response = await _supabase
        .from('user_push_tokens')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((item) => PushToken.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
