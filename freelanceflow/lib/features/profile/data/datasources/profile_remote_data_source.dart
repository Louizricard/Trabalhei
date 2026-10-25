import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/storage_service.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../domain/entities/portfolio_item.dart';
import '../../domain/entities/profile_update.dart';

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
      return list
          .map((json) => UserReview.fromJson(json as Map<String, dynamic>))
          .toList();
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
      return list
          .map((json) => PortfolioItem.fromJson(json as Map<String, dynamic>))
          .toList();
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
    final response = await _supabase
        .from('portfolio_items')
        .insert({
          'freelancer_id': userId,
          'title': title,
          'description': description,
          'image_url': imageUrl,
          'project_url': projectUrl,
          'tags': tags,
        })
        .select()
        .single();

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
      var q = _supabase
          .from('profiles')
          .select()
          .eq('role', 'freelancer')
          .isFilter('deleted_at', null);

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
      final profiles = (response as List<dynamic>)
          .map((json) => UserProfile.fromJson(json as Map<String, dynamic>))
          .toList();
      // Plano Pro tem prioridade na busca (mantém a ordenação escolhida dentro de cada grupo).
      return [
        ...profiles.where((p) => p.isPro),
        ...profiles.where((p) => !p.isPro),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> updateProfile({
    required String userId,
    required ProfileUpdate update,
  }) async {
    await _supabase.from('profiles').update(update.toJson()).eq('id', userId);
  }

  /// Currículo em PDF no bucket privado `resumes` (`<user_id>/curriculo-*.pdf`).
  /// O perfil guarda o endereço no formato público, trocado por um link
  /// assinado ao abrir; o arquivo anterior é apagado.
  Future<String> uploadResume({
    required String userId,
    required Uint8List bytes,
    String? previousUrl,
  }) async {
    final bucket = _supabase.storage.from('resumes');
    final path =
        '$userId/curriculo-${DateTime.now().millisecondsSinceEpoch}.pdf';
    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(contentType: 'application/pdf'),
    );
    final url = bucket.getPublicUrl(path);
    await _supabase
        .from('profiles')
        .update({'resume_url': url})
        .eq('id', userId);
    if (previousUrl != null) await _deleteResumeFile(previousUrl);
    return url;
  }

  Future<void> removeResume({
    required String userId,
    required String url,
  }) async {
    await _supabase
        .from('profiles')
        .update({'resume_url': null})
        .eq('id', userId);
    await _deleteResumeFile(url);
  }

  Future<void> _deleteResumeFile(String url) async {
    final object = privateStorageObject(url);
    if (object == null) return;
    try {
      await _supabase.storage.from(object.bucket).remove([object.path]);
    } catch (_) {
      // Arquivo antigo que não sai não impede a troca do currículo.
    }
  }

  Future<String> uploadAvatar({
    required String userId,
    required dynamic bytes,
    required String fileExt,
  }) async {
    // Convenção de storage: <bucket>/<user_id>/<arquivo> (policy exige a pasta do dono).
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

    await _supabase.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$fileExt'),
        );

    final publicUrl = _supabase.storage.from('avatars').getPublicUrl(path);

    await _supabase
        .from('profiles')
        .update({'avatar_url': publicUrl})
        .eq('id', userId);

    return publicUrl;
  }
}
