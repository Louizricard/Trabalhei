import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../domain/entities/profile_update.dart';
import '../../../../core/config/supabase_client.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../data/datasources/profile_remote_data_source.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/portfolio_item.dart';
import '../../domain/repositories/profile_repository.dart';

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>((
  ref,
) {
  final supabase = ref.watch(supabaseClientProvider);
  return ProfileRemoteDataSource(supabase);
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final remoteDataSource = ref.watch(profileRemoteDataSourceProvider);
  return ProfileRepositoryImpl(remoteDataSource);
});

// Perfil de qualquer usuário (por ID)
final publicProfileProvider = FutureProvider.family
    .autoDispose<UserProfile?, String>((ref, userId) async {
      final repository = ref.watch(profileRepositoryProvider);
      return repository.getProfileById(userId);
    });

// Avaliações de qualquer usuário (por ID)
final publicReviewsProvider = FutureProvider.family
    .autoDispose<List<UserReview>, String>((ref, userId) async {
      final repository = ref.watch(profileRepositoryProvider);
      return repository.getUserReviews(userId);
    });

// Itens de portfólio de um usuário
final userPortfolioProvider = FutureProvider.family
    .autoDispose<List<PortfolioItem>, String>((ref, userId) async {
      final repository = ref.watch(profileRepositoryProvider);
      return repository.getPortfolioItems(userId);
    });

// Avaliações do usuário autenticado
final userReviewsProvider = FutureProvider.autoDispose<List<UserReview>>((
  ref,
) async {
  final repository = ref.watch(profileRepositoryProvider);
  final user = ref.watch(authProvider).value;
  if (user == null) return [];

  return repository.getUserReviews(user.id);
});

// Filtros para a busca de freelancers
class FreelancerSearchFilter {
  final String query;
  final String? skill;
  final double? minRating;
  final double? minHourlyRate;
  final double? maxHourlyRate;
  final String? availabilityStatus;
  final String orderBy;

  const FreelancerSearchFilter({
    this.query = '',
    this.skill,
    this.minRating,
    this.minHourlyRate,
    this.maxHourlyRate,
    this.availabilityStatus,
    this.orderBy = 'rating_desc',
  });

  FreelancerSearchFilter copyWith({
    String? query,
    String? skill,
    double? minRating,
    double? minHourlyRate,
    double? maxHourlyRate,
    String? availabilityStatus,
    String? orderBy,
  }) {
    return FreelancerSearchFilter(
      query: query ?? this.query,
      skill: skill ?? this.skill,
      minRating: minRating ?? this.minRating,
      minHourlyRate: minHourlyRate ?? this.minHourlyRate,
      maxHourlyRate: maxHourlyRate ?? this.maxHourlyRate,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      orderBy: orderBy ?? this.orderBy,
    );
  }

  bool get hasActiveFilters =>
      (skill != null && skill!.isNotEmpty && skill != 'Todos') ||
      (minRating != null && minRating! > 0) ||
      (minHourlyRate != null && minHourlyRate! > 0) ||
      (maxHourlyRate != null && maxHourlyRate! > 0) ||
      (availabilityStatus != null &&
          availabilityStatus!.isNotEmpty &&
          availabilityStatus != 'all') ||
      orderBy != 'rating_desc';
}

class FreelancerSearchFilterNotifier
    extends StateNotifier<FreelancerSearchFilter> {
  FreelancerSearchFilterNotifier() : super(const FreelancerSearchFilter());

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void setSkill(String? skill) {
    state = state.copyWith(skill: skill);
  }

  void updateFilters({
    double? minRating,
    double? minHourlyRate,
    double? maxHourlyRate,
    String? availabilityStatus,
    String? orderBy,
  }) {
    state = state.copyWith(
      minRating: minRating,
      minHourlyRate: minHourlyRate,
      maxHourlyRate: maxHourlyRate,
      availabilityStatus: availabilityStatus,
      orderBy: orderBy,
    );
  }

  void resetFilters() {
    state = FreelancerSearchFilter(query: state.query);
  }
}

final freelancerSearchFilterProvider =
    StateNotifierProvider<
      FreelancerSearchFilterNotifier,
      FreelancerSearchFilter
    >((ref) {
      return FreelancerSearchFilterNotifier();
    });

// Lista de freelancers filtrados
final freelancersListProvider = FutureProvider.autoDispose<List<UserProfile>>((
  ref,
) async {
  final repository = ref.watch(profileRepositoryProvider);
  final filter = ref.watch(freelancerSearchFilterProvider);

  return repository.searchFreelancers(
    query: filter.query,
    skill: filter.skill,
    minRating: filter.minRating,
    minHourlyRate: filter.minHourlyRate,
    maxHourlyRate: filter.maxHourlyRate,
    availabilityStatus: filter.availabilityStatus,
    orderBy: filter.orderBy,
  );
});

// Adicionar projeto ao portfólio
final addPortfolioItemProvider =
    Provider<
      Future<PortfolioItem> Function({
        required String title,
        required String description,
        required String imageUrl,
        String? projectUrl,
        List<String> tags,
      })
    >((ref) {
      final repository = ref.watch(profileRepositoryProvider);
      final user = ref.watch(authProvider).value;

      return ({
        required String title,
        required String description,
        required String imageUrl,
        String? projectUrl,
        List<String> tags = const [],
      }) async {
        if (user == null) throw Exception('Não autenticado');

        final item = await repository.addPortfolioItem(
          userId: user.id,
          title: title,
          description: description,
          imageUrl: imageUrl,
          projectUrl: projectUrl,
          tags: tags,
        );

        ref.invalidate(userPortfolioProvider(user.id));
        return item;
      };
    });

// Deletar item do portfólio
final deletePortfolioItemProvider =
    Provider<Future<void> Function(String itemId)>((ref) {
      final repository = ref.watch(profileRepositoryProvider);
      final user = ref.watch(authProvider).value;

      return (String itemId) async {
        if (user == null) throw Exception('Não autenticado');

        await repository.deletePortfolioItem(itemId);
        ref.invalidate(userPortfolioProvider(user.id));
      };
    });

// Atualizar perfil
final updateProfileProvider = Provider<Future<void> Function(ProfileUpdate)>((
  ref,
) {
  final repository = ref.watch(profileRepositoryProvider);
  final user = ref.watch(authProvider).value;

  return (update) async {
    if (user == null) {
      throw const AppMessageException('Entre de novo para editar o perfil.');
    }
    await repository.updateProfile(userId: user.id, update: update);
    ref.invalidate(authProvider);
    ref.invalidate(publicProfileProvider(user.id));
  };
});

// Upload de avatar
final uploadAvatarProvider =
    Provider<Future<String> Function(dynamic bytes, String fileExt)>((ref) {
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
        ref.invalidate(publicProfileProvider(user.id));
        return publicUrl;
      };
    });
