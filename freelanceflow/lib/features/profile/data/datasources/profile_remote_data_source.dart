import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../domain/entities/portfolio_item.dart';

class ProfileRemoteDataSource {
  final SupabaseClient _supabase;

  ProfileRemoteDataSource(this._supabase);

  SupabaseClient get supabase => _supabase;

  Future<UserProfile?> getProfileById(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return UserProfile.fromJson(response);
    } catch (_) {
      return null;
    }
  }

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

  Future<List<PortfolioItem>> getPortfolioItems(String userId) async {
    try {
      final response = await _supabase
          .from('portfolio_items')
          .select()
          .eq('freelancer_id', userId)
          .order('created_at', ascending: false);

      final list = response as List<dynamic>;
      return list.map((json) => PortfolioItem.fromJson(json as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<PortfolioItem> addPortfolioItem({
    required String userId,
    required String title,
    required String description,
    required String imageUrl,
    String? projectUrl,
    List<String> tags = const [],
  }) async {
    final response = await _supabase.from('portfolio_items').insert({
      'freelancer_id': userId,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'project_url': projectUrl,
      'tags': tags,
    }).select().single();

    return PortfolioItem.fromJson(response);
  }

  Future<void> deletePortfolioItem(String itemId) async {
    await _supabase.from('portfolio_items').delete().eq('id', itemId);
  }

  Future<List<UserProfile>> searchFreelancers({
    String? query,
    String? skill,
    double? minRating,
    double? minHourlyRate,
    double? maxHourlyRate,
    String? availabilityStatus,
    String orderBy = 'rating_desc',
  }) async {
    try {
      var q = _supabase.from('profiles').select().eq('role', 'freelancer');

      if (query != null && query.trim().isNotEmpty) {
        final term = query.trim();
        q = q.or('full_name.ilike.%$term%,bio.ilike.%$term%');
      }

      if (skill != null && skill.isNotEmpty && skill.toLowerCase() != 'todos') {
        q = q.contains('skills', [skill]);
      }

      if (minRating != null && minRating > 0) {
        q = q.gte('rating', minRating);
      }

      if (minHourlyRate != null && minHourlyRate > 0) {
        q = q.gte('hourly_rate', minHourlyRate);
      }

      if (maxHourlyRate != null && maxHourlyRate > 0) {
        q = q.lte('hourly_rate', maxHourlyRate);
      }

      if (availabilityStatus != null &&
          availabilityStatus.isNotEmpty &&
          availabilityStatus != 'all') {
        q = q.eq('availability_status', availabilityStatus);
      }

      PostgrestTransformBuilder<List<Map<String, dynamic>>> transform;
      switch (orderBy) {
        case 'jobs_desc':
          transform = q.order('completed_jobs_count', ascending: false);
          break;
        case 'rate_asc':
          transform = q.order('hourly_rate', ascending: true);
          break;
        case 'rate_desc':
          transform = q.order('hourly_rate', ascending: false);
          break;
        case 'rating_desc':
        default:
          transform = q.order('rating', ascending: false);
          break;
      }

      final response = await transform;
      final list = response as List<dynamic>;
      return list.map((json) => UserProfile.fromJson(json as Map<String, dynamic>)).toList();
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
