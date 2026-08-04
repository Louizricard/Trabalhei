import '../../domain/entities/portfolio_item.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource _remoteDataSource;

  ProfileRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<UserReview>> getUserReviews(String userId) {
    return _remoteDataSource.getUserReviews(userId);
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
