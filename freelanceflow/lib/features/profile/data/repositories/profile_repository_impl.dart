import '../../../auth/domain/entities/user_profile.dart';
import 'dart:typed_data';
import '../../domain/entities/portfolio_item.dart';
import '../../domain/entities/profile_update.dart';
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
    required ProfileUpdate update,
  }) {
    return _remoteDataSource.updateProfile(userId: userId, update: update);
  }

  @override
  Future<String> uploadResume({
    required String userId,
    required Uint8List bytes,
    String? previousUrl,
  }) {
    return _remoteDataSource.uploadResume(
      userId: userId,
      bytes: bytes,
      previousUrl: previousUrl,
    );
  }

  @override
  Future<void> removeResume({required String userId, required String url}) {
    return _remoteDataSource.removeResume(userId: userId, url: url);
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
