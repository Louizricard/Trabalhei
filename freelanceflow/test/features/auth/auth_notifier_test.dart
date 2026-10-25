import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/features/auth/domain/entities/user_profile.dart';
import 'package:trabalhei/features/auth/domain/repositories/auth_repository.dart';
import 'package:trabalhei/features/auth/presentation/providers/auth_state_provider.dart';

class _FailingAuthRepository implements AuthRepository {
  @override
  Stream<UserProfile?> get authStateChanges => const Stream.empty();

  @override
  Future<UserProfile?> getCurrentUser() async => null;

  @override
  Future<UserProfile> signInWithEmailPassword({
    required String email,
    required String password,
  }) async => throw Exception('E-mail ou senha incorretos.');

  @override
  Future<UserProfile> signUpWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async => throw Exception('Falha ao cadastrar.');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('login ou cadastro com erro deixa o usuário deslogado, sem estado de '
      'erro (que travava a navegação)', () async {
    final notifier = AuthNotifier(_FailingAuthRepository());
    await Future<void>.delayed(Duration.zero);

    await expectLater(notifier.signIn('a@b.com', 'errada'), throwsException);
    expect(notifier.state.hasError, isFalse);
    expect(notifier.state.valueOrNull, isNull);

    await expectLater(
      notifier.signUp(
        email: 'a@b.com',
        password: '12345678',
        fullName: 'Fulano',
        role: UserRole.freelancer,
      ),
      throwsException,
    );
    expect(notifier.state.hasError, isFalse);
    notifier.dispose();
  });
}
