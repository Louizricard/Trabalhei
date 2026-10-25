import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;

  AuthRepositoryImpl(this._remoteDataSource);

  @override
  Stream<UserProfile?> get authStateChanges {
    return _remoteDataSource.authStateChanges.asyncMap(
      (_) => _remoteDataSource.getCurrentUserProfile(),
    );
  }

  @override
  Future<UserProfile?> getCurrentUser() {
    return _remoteDataSource.getCurrentUserProfile();
  }

  @override
  Future<UserProfile> signInWithEmailPassword({
    required String email,
    required String password,
  }) {
    return _remoteDataSource.signIn(email: email, password: password);
  }

  @override
  Future<UserProfile> signUpWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) {
    return _remoteDataSource.signUp(
      email: email,
      password: password,
      fullName: fullName,
      role: role,
    );
  }

  @override
  Future<void> sendPasswordReset(String email) {
    return _remoteDataSource.sendPasswordReset(email);
  }

  @override
  Future<void> updatePassword(String newPassword) {
    return _remoteDataSource.updatePassword(newPassword);
  }

  @override
  Future<void> resendSignupConfirmation(String email) {
    return _remoteDataSource.resendSignupConfirmation(email);
  }

  @override
  Future<void> verifyEmailLink({
    required String tokenHash,
    required bool recovery,
  }) {
    return _remoteDataSource.verifyEmailLink(
      tokenHash: tokenHash,
      recovery: recovery,
    );
  }

  @override
  Future<void> signOut() {
    return _remoteDataSource.signOut();
  }

  @override
  Future<void> deleteAccount() {
    return _remoteDataSource.deleteAccount();
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) {
    return _remoteDataSource.updateProfile(profile);
  }

  @override
  Future<UserProfile> switchRole(UserRole newRole) {
    return _remoteDataSource.switchRole(newRole);
  }
}
