import '../../../auth/domain/entities/user_profile.dart';
import '../../domain/entities/portfolio_item.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource _remoteDataSource;

  ProfileRepositoryImpl(this._remoteDataSource);

  @override
  Future<UserProfile?> getProfileById(String userId) {
    return _remoteDataSource.getProfileById(userId);
  }

  @override
  Future<List<UserReview>> getUserReviews(String userId) {
    return _remoteDataSource.getUserReviews(userId);
  }

  @override
  Future<List<PortfolioItem>> getPortfolioItems(String userId) {
    return _remoteDataSource.getPortfolioItems(userId);
  }

  @override
  Future<PortfolioItem> addPortfolioItem({
    required String userId,
    required String title,
    required String description,
    required String imageUrl,
    String? projectUrl,
    List<String> tags = const [],
  }) {
    return _remoteDataSource.addPortfolioItem(
      userId: userId,
      title: title,
      description: description,
      imageUrl: imageUrl,
      projectUrl: projectUrl,
      tags: tags,
    );
  }

  @override
  Future<void> deletePortfolioItem(String itemId) {
    return _remoteDataSource.deletePortfolioItem(itemId);
  }

  @override
  Future<List<UserProfile>> searchFreelancers({
    String? query,
    String? skill,
    double? minRating,
    double? minHourlyRate,
    double? maxHourlyRate,
    String? availabilityStatus,
    String orderBy = 'rating_desc',
  }) {
    return _remoteDataSource.searchFreelancers(
      query: query,
      skill: skill,
      minRating: minRating,
      minHourlyRate: minHourlyRate,
      maxHourlyRate: maxHourlyRate,
      availabilityStatus: availabilityStatus,
      orderBy: orderBy,
    );
  }

  @override
  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? bio,
    double? hourlyRate,
    List<String>? skills,
  }) {
    return _remoteDataSource.updateProfile(
      userId: userId,
      fullName: fullName,
      bio: bio,
      hourlyRate: hourlyRate,
      skills: skills,
    );
  }

  @override
  Future<String> uploadAvatar({
    required String userId,
    required dynamic bytes,
    required String fileExt,
  }) {
    return _remoteDataSource.uploadAvatar(
      userId: userId,
      bytes: bytes,
      fileExt: fileExt,
    );
  }
}
