import '../entities/user_profile.dart';

abstract class AuthRepository {
  Stream<UserProfile?> get authStateChanges;
  Future<UserProfile?> getCurrentUser();
  Future<UserProfile> signInWithEmailPassword({
    required String email,
    required String password,
  });
  Future<UserProfile> signUpWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  });
  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String newPassword);
  Future<void> signOut();
  Future<void> deleteAccount();
  Future<UserProfile> updateProfile(UserProfile profile);
  Future<UserProfile> switchRole(UserRole newRole);
}
