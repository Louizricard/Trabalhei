import '../../domain/entities/push_token.dart';
import '../../domain/repositories/push_token_repository.dart';
import '../datasources/push_token_remote_data_source.dart';

class PushTokenRepositoryImpl implements PushTokenRepository {
  final PushTokenRemoteDataSource _remoteDataSource;

  PushTokenRepositoryImpl(this._remoteDataSource);

  @override
  Future<void> saveToken({
    required String userId,
    required String token,
    required String platform,
  }) {
    return _remoteDataSource.upsertToken(
      userId: userId,
      token: token,
      platform: platform,
    );
  }

  @override
  Future<void> deleteToken({required String token}) {
    return _remoteDataSource.deleteToken(token: token);
  }

  @override
  Future<List<PushToken>> getTokensForUser({required String userId}) {
    return _remoteDataSource.getTokensForUser(userId: userId);
  }
}
