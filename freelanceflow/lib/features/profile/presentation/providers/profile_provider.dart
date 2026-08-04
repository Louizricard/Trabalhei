import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_client.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../data/datasources/profile_remote_data_source.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/portfolio_item.dart';
import '../../domain/repositories/profile_repository.dart';

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ProfileRemoteDataSource(supabase);
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final remoteDataSource = ref.watch(profileRemoteDataSourceProvider);
  return ProfileRepositoryImpl(remoteDataSource);
});

final userReviewsProvider = FutureProvider<List<UserReview>>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  final user = ref.watch(authProvider).value;
  if (user == null) return [];

  return repository.getUserReviews(user.id);
});

final updateProfileProvider = Provider<Future<void> Function({
  String? fullName,
  String? bio,
  double? hourlyRate,
  List<String>? skills,
})>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  final user = ref.watch(authProvider).value;

  return ({fullName, bio, hourlyRate, skills}) async {
    if (user == null) throw Exception('Não autenticado');

    await repository.updateProfile(
      userId: user.id,
      fullName: fullName,
      bio: bio,
      hourlyRate: hourlyRate,
      skills: skills,
    );
    ref.invalidate(authProvider);
  };
});

final uploadAvatarProvider = Provider<Future<String> Function(dynamic bytes, String fileExt)>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  final user = ref.watch(authProvider).value;

  return (bytes, fileExt) async {
    if (user == null) throw Exception('Não autenticado');

    final publicUrl = await repository.uploadAvatar(
      userId: user.id,
      bytes: bytes,
      fileExt: fileExt,
    );

    ref.invalidate(authProvider);
    return publicUrl;
  };
});
