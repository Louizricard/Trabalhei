import '../entities/portfolio_item.dart';

abstract class ProfileRepository {
  Future<List<UserReview>> getUserReviews(String userId);

  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? bio,
    double? hourlyRate,
    List<String>? skills,
  });

  Future<String> uploadAvatar({
    required String userId,
    required dynamic bytes,
    required String fileExt,
  });
}
