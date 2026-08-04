import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/portfolio_item.dart';

class ProfileRemoteDataSource {
  final SupabaseClient _supabase;

  ProfileRemoteDataSource(this._supabase);

  SupabaseClient get supabase => _supabase;

  Future<List<UserReview>> getUserReviews(String userId) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select('''
            id,
            rating,
            comment,
            created_at,
            profiles:reviewer_id (full_name),
            contracts:contract_id (jobs (title))
          ''')
          .eq('target_id', userId)
          .order('created_at', ascending: false);

      final list = response as List<dynamic>;
      return list.map((json) => UserReview.fromJson(json as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? bio,
    double? hourlyRate,
    List<String>? skills,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (fullName != null) updates['full_name'] = fullName;
    if (bio != null) updates['bio'] = bio;
    if (hourlyRate != null) updates['hourly_rate'] = hourlyRate;
    if (skills != null) updates['skills'] = skills;

    await _supabase.from('profiles').update(updates).eq('id', userId);
  }

  Future<String> uploadAvatar({
    required String userId,
    required dynamic bytes,
    required String fileExt,
  }) async {
    final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final path = fileName;

    await _supabase.storage.from('avatars').uploadBinary(
          path,
          bytes,
        );

    final publicUrl = _supabase.storage.from('avatars').getPublicUrl(path);

    await _supabase.from('profiles').update({
      'avatar_url': publicUrl,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);

    return publicUrl;
  }
}
