import '../../../auth/domain/entities/user_profile.dart';
import '../entities/portfolio_item.dart';

abstract class ProfileRepository {
  Future<UserProfile?> getProfileById(String userId);

  Future<List<UserReview>> getUserReviews(String userId);

  Future<List<PortfolioItem>> getPortfolioItems(String userId);

  Future<PortfolioItem> addPortfolioItem({
    required String userId,
    required String title,
    required String description,
    required String imageUrl,
    String? projectUrl,
    List<String> tags = const [],
  });

  Future<void> deletePortfolioItem(String itemId);

  Future<List<UserProfile>> searchFreelancers({
    String? query,
    String? skill,
    double? minRating,
    double? minHourlyRate,
    double? maxHourlyRate,
    String? availabilityStatus,
    String orderBy = 'rating_desc',
  });

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
