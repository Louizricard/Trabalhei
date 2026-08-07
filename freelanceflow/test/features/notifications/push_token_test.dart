import 'package:flutter_test/flutter_test.dart';
import 'package:freelanceflow/features/notifications/domain/entities/push_token.dart';
import 'package:freelanceflow/features/notifications/domain/repositories/push_token_repository.dart';
import 'package:freelanceflow/features/notifications/data/repositories/push_token_repository_impl.dart';
import 'package:freelanceflow/features/notifications/data/datasources/push_token_remote_data_source.dart';
import 'package:freelanceflow/features/notifications/presentation/services/notification_service.dart';

class MockPushTokenRemoteDataSource implements PushTokenRemoteDataSource {
  final Map<String, PushToken> storage = {};

  @override
  Future<void> upsertToken({
    required String userId,
    required String token,
    required String platform,
  }) async {
    storage[token] = PushToken(
      id: 'mock-id-$token',
      userId: userId,
      token: token,
      platform: platform,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteToken({required String token}) async {
    storage.remove(token);
  }

  @override
  Future<List<PushToken>> getTokensForUser({required String userId}) async {
    return storage.values.where((t) => t.userId == userId).toList();
  }
}

void main() {
  group('PushToken Entity Tests', () {
    test('parses PushToken from JSON correctly', () {
      final json = {
        'id': 'token-uuid-1',
        'user_id': 'user-uuid-123',
        'token': 'fcm-sample-token-abc',
        'platform': 'android',
        'created_at': '2026-08-06T10:00:00.000Z',
        'updated_at': '2026-08-06T10:05:00.000Z',
      };

      final pushToken = PushToken.fromJson(json);

      expect(pushToken.id, equals('token-uuid-1'));
      expect(pushToken.userId, equals('user-uuid-123'));
      expect(pushToken.token, equals('fcm-sample-token-abc'));
      expect(pushToken.platform, equals('android'));
      expect(pushToken.createdAt, isA<DateTime>());
      expect(pushToken.updatedAt, isA<DateTime>());
    });

    test('serializes PushToken to JSON map correctly', () {
      final now = DateTime.now();
      final pushToken = PushToken(
        id: 'token-uuid-2',
        userId: 'user-uuid-456',
        token: 'fcm-token-xyz',
        platform: 'ios',
        createdAt: now,
        updatedAt: now,
      );

      final json = pushToken.toJson();

      expect(json['id'], equals('token-uuid-2'));
      expect(json['user_id'], equals('user-uuid-456'));
      expect(json['token'], equals('fcm-token-xyz'));
      expect(json['platform'], equals('ios'));
      expect(json['created_at'], isNotNull);
      expect(json['updated_at'], isNotNull);
    });

    test('copyWith updates specific properties without modifying others', () {
      final now = DateTime.now();
      final original = PushToken(
        id: 'token-1',
        userId: 'user-1',
        token: 'fcm-original',
        platform: 'android',
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(token: 'fcm-refreshed');

      expect(updated.token, equals('fcm-refreshed'));
      expect(updated.userId, equals('user-1'));
      expect(updated.platform, equals('android'));
      expect(updated.id, equals('token-1'));
    });
  });

  group('PushTokenRepository Tests', () {
    late MockPushTokenRemoteDataSource mockDataSource;
    late PushTokenRepository repository;

    setUp(() {
      mockDataSource = MockPushTokenRemoteDataSource();
      repository = PushTokenRepositoryImpl(mockDataSource);
    });

    test('saves push token via repository and retrieves it', () async {
      await repository.saveToken(
        userId: 'user-test-789',
        token: 'test-fcm-token-123',
        platform: 'android',
      );

      final tokens = await repository.getTokensForUser(userId: 'user-test-789');
      expect(tokens.length, equals(1));
      expect(tokens.first.token, equals('test-fcm-token-123'));
      expect(tokens.first.platform, equals('android'));
    });

    test('deletes push token correctly on logout', () async {
      await repository.saveToken(
        userId: 'user-test-789',
        token: 'test-fcm-token-to-delete',
        platform: 'android',
      );

      var tokens = await repository.getTokensForUser(userId: 'user-test-789');
      expect(tokens.length, equals(1));

      await repository.deleteToken(token: 'test-fcm-token-to-delete');

      tokens = await repository.getTokensForUser(userId: 'user-test-789');
      expect(tokens.isEmpty, isTrue);
    });
  });

  group('NotificationService Route Parsing Tests', () {
    final service = NotificationService();

    test('extracts direct route when provided in payload', () {
      final route = service.extractRouteFromData({'route': '/profile'});
      expect(route, equals('/profile'));
    });

    test('extracts chat room route from conversation_id payload', () {
      final route = service.extractRouteFromData({
        'conversation_id': 'conv-uuid-999',
      });
      expect(route, equals('/chat/conv-uuid-999'));
    });

    test('extracts job details route from job_id payload', () {
      final route = service.extractRouteFromData({'job_id': 'job-uuid-111'});
      expect(route, equals('/jobs/job-uuid-111'));
    });

    test('extracts job proposals route when proposal_id is present', () {
      final route = service.extractRouteFromData({
        'job_id': 'job-uuid-111',
        'proposal_id': 'prop-uuid-222',
      });
      expect(route, equals('/jobs/job-uuid-111/proposals'));
    });

    test('extracts payments route when type is payments', () {
      final route = service.extractRouteFromData({'type': 'payments'});
      expect(route, equals('/payments'));
    });

    test('returns null when payload has no recognized navigation keys', () {
      final route = service.extractRouteFromData({'unrelated_key': 'value'});
      expect(route, isNull);
    });
  });
}
