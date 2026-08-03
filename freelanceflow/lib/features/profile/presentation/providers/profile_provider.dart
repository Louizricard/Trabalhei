import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_client.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../domain/entities/portfolio_item.dart';

final userReviewsProvider = FutureProvider<List<UserReview>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final user = ref.watch(authProvider).value;
  if (user == null) return [];

  try {
    final response = await supabase
        .from('reviews')
        .select('''
          id,
          rating,
          comment,
          created_at,
          profiles:reviewer_id (full_name),
          contracts:contract_id (jobs (title))
        ''')
        .eq('target_id', user.id)
        .order('created_at', ascending: false);

    final list = response as List<dynamic>;
    return list.map((json) => UserReview.fromJson(json as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
});

final updateProfileProvider = Provider<Future<void> Function({
  String? fullName,
  String? bio,
  double? hourlyRate,
  List<String>? skills,
})>((ref) {
  return ({fullName, bio, hourlyRate, skills}) async {
    final supabase = ref.watch(supabaseClientProvider);
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Não autenticado');

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (fullName != null) updates['full_name'] = fullName;
    if (bio != null) updates['bio'] = bio;
    if (hourlyRate != null) updates['hourly_rate'] = hourlyRate;
    if (skills != null) updates['skills'] = skills;

    await supabase.from('profiles').update(updates).eq('id', user.id);
    ref.invalidate(authProvider);
  };
});
