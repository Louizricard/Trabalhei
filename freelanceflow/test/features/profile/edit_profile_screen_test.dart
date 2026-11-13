import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trabalhei/features/auth/domain/entities/user_profile.dart';
import 'package:trabalhei/features/auth/domain/repositories/auth_repository.dart';
import 'package:trabalhei/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:trabalhei/features/profile/domain/entities/profile_draft.dart';
import 'package:trabalhei/features/profile/domain/entities/profile_update.dart';
import 'package:trabalhei/features/profile/domain/repositories/profile_repository.dart';
import 'package:trabalhei/features/profile/presentation/providers/profile_provider.dart';
import 'package:trabalhei/features/profile/presentation/screens/edit_profile_screen.dart';

UserProfile _user(UserRole role) => UserProfile(
  id: 'u1',
  email: 'ana@exemplo.com',
  fullName: 'Ana Lima',
  role: role,
  headline: 'Designer de marcas',
  location: 'Goiânia, GO',
  websiteUrl: 'https://ana.design',
  skills: const ['Branding'],
  category: 'Design',
  createdAt: DateTime(2026),
);

class _Auth implements AuthRepository {
  final UserProfile user;
  _Auth(this.user);

  @override
  Stream<UserProfile?> get authStateChanges => const Stream.empty();

  @override
  Future<UserProfile?> getCurrentUser() async => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Profiles implements ProfileRepository {
  final saved = <ProfileUpdate>[];

  @override
  Future<void> updateProfile({
    required String userId,
    required ProfileUpdate update,
  }) async => saved.add(update);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Profiles> _open(
  WidgetTester tester,
  UserRole role, {
  Size size = const Size(375, 812),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final profiles = _Profiles();
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(path: '/profile', builder: (_, _) => const Text('meu perfil')),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const EditProfileScreen(),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_Auth(_user(role))),
        profileRepositoryProvider.overrideWithValue(profiles),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  router.push('/profile/edit');
  await tester.pumpAndSettle();
  return profiles;
}

Finder get _form => find.byType(Scrollable).first;

void main() {
  testWidgets('freelancer vê as seções com os dados salvos, no celular', (
    tester,
  ) async {
    await _open(tester, UserRole.freelancer);

    expect(tester.takeException(), isNull);
    expect(find.text('Informações pessoais'), findsOneWidget);
    expect(find.text('Ana Lima'), findsOneWidget);
    for (final section in ['Profissional', 'Apresentação', 'Links']) {
      await tester.scrollUntilVisible(
        find.text(section),
        200,
        scrollable: _form,
      );
    }
    expect(find.text('https://ana.design'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Enviar PDF'),
      200,
      scrollable: _form,
    );
    expect(find.byKey(const Key('profile-save')), findsOneWidget);
  });

  testWidgets('contratante vê empresa e não vê a seção profissional', (
    tester,
  ) async {
    await _open(tester, UserRole.client);

    expect(find.textContaining('Empresa', findRichText: true), findsOneWidget);
    expect(find.text('Profissional'), findsNothing);
    expect(find.text('Currículo'), findsNothing);
  });

  testWidgets('voltar com alterações pergunta antes de descartar', (
    tester,
  ) async {
    await _open(tester, UserRole.freelancer);
    await tester.enterText(find.byKey(const Key('profile-name')), 'Ana Souza');
    await tester.pump();

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar alterações?'), findsOneWidget);

    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Souza'), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('meu perfil'), findsOneWidget);
  });

  testWidgets('voltar sem alterações sai direto', (tester) async {
    await _open(tester, UserRole.freelancer);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar alterações?'), findsNothing);
    expect(find.text('meu perfil'), findsOneWidget);
  });

  testWidgets('salvar grava o rascunho com área e volta ao perfil', (
    tester,
  ) async {
    final profiles = await _open(tester, UserRole.freelancer);
    await tester.enterText(find.byKey(const Key('profile-name')), 'Ana Souza');
    await tester.tap(find.byKey(const Key('profile-save')));
    await tester.pumpAndSettle();

    expect(profiles.saved, hasLength(1));
    final json = profiles.saved.single.toJson();
    expect(json['full_name'], 'Ana Souza');
    expect(json['skills'], ['Branding']);
    expect(json['category'], 'Design');
    expect(find.text('meu perfil'), findsOneWidget);
  });

  testWidgets('nome vazio não salva', (tester) async {
    final profiles = await _open(tester, UserRole.freelancer);
    await tester.enterText(find.byKey(const Key('profile-name')), '  ');
    await tester.tap(find.byKey(const Key('profile-save')));
    await tester.pumpAndSettle();

    expect(profiles.saved, isEmpty);
    expect(find.text('Revise os campos destacados.'), findsOneWidget);
  });

  testWidgets('no desktop o índice leva à seção', (tester) async {
    await _open(tester, UserRole.freelancer, size: const Size(1280, 800));
    final index = find.widgetWithText(TextButton, 'Links');
    expect(index, findsOneWidget);
    await tester.tap(index);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('https://ana.design').hitTestable(), findsOneWidget);
  });

  group('ProfileDraft', () {
    final user = _user(UserRole.freelancer);

    test('espaços nas pontas não contam como alteração', () {
      final initial = ProfileDraft.fromUser(user);
      expect(initial.copyWith(fullName: 'Ana Lima '), initial);
      expect(initial.copyWith(fullName: 'Ana'), isNot(initial));
    });

    test('cliente não grava área; freelancer grava e limpa subárea', () {
      final draft = ProfileDraft.fromUser(user);
      final client = draft.toUpdate(isFreelancer: false, parseRate: (_) => 0);
      expect(client.toJson().containsKey('category'), isFalse);

      final freelancer = draft
          .copyWith(category: (area: 'Tecnologia', subcategory: 'Mobile'))
          .toUpdate(isFreelancer: true, parseRate: (_) => 80);
      final json = freelancer.toJson();
      expect(json['category'], 'Tecnologia');
      expect(json['subcategory'], 'Mobile');
      expect(json['hourly_rate'], 80);
    });
  });
}
