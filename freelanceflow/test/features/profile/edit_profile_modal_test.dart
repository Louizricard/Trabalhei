import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/features/auth/domain/entities/user_profile.dart';
import 'package:trabalhei/features/auth/domain/repositories/auth_repository.dart';
import 'package:trabalhei/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:trabalhei/features/profile/presentation/widgets/edit_profile_modal.dart';

final _freelancer = UserProfile(
  id: 'u1',
  email: 'ana@exemplo.com',
  fullName: 'Ana Lima',
  role: UserRole.freelancer,
  headline: 'Designer de produto',
  location: 'Goiânia, GO',
  websiteUrl: 'https://ana.dev',
  createdAt: DateTime(2026),
);

class _SignedInRepository implements AuthRepository {
  @override
  Stream<UserProfile?> get authStateChanges => const Stream.empty();

  @override
  Future<UserProfile?> getCurrentUser() async => _freelancer;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('editar perfil mostra os novos campos e cabe no celular', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_SignedInRepository()),
        ],
        child: MaterialApp(
          home: Scaffold(body: EditProfileModal(user: _freelancer)),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Título profissional'), findsOneWidget);
    expect(find.text('Designer de produto'), findsOneWidget);
    expect(find.text('Cidade'), findsOneWidget);
    final form = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('GitHub'), 200, scrollable: form);
    expect(find.text('LinkedIn'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Enviar PDF'),
      200,
      scrollable: form,
    );
    expect(find.text('Currículo (PDF, até 5 MB)'), findsOneWidget);
  });
}
