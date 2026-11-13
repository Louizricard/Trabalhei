import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trabalhei/features/auth/domain/entities/user_profile.dart';
import 'package:trabalhei/features/auth/domain/repositories/auth_repository.dart';
import 'package:trabalhei/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:trabalhei/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:trabalhei/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:trabalhei/features/dashboard/presentation/screens/client_dashboard_screen.dart';
import 'package:trabalhei/features/dashboard/presentation/screens/freelancer_dashboard_screen.dart';

class _Repo implements AuthRepository {
  final UserProfile user;
  _Repo(this.user);

  @override
  Stream<UserProfile?> get authStateChanges => const Stream.empty();

  @override
  Future<UserProfile?> getCurrentUser() async => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, UserRole role, Widget screen) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(path: '/dashboard', builder: (_, _) => screen),
      GoRoute(
        path: '/jobs',
        builder: (_, state) => Text('mural:${state.extra}'),
      ),
      GoRoute(path: '/chat', builder: (_, _) => const Text('mensagens')),
      GoRoute(path: '/freelancers', builder: (_, _) => const Text('talentos')),
      GoRoute(path: '/jobs/create', builder: (_, _) => const Text('nova')),
    ],
  );
  final user = UserProfile(
    id: 'u1',
    email: 'pessoa@exemplo.com',
    fullName: 'Pessoa Teste',
    role: role,
    createdAt: DateTime(2026),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_Repo(user)),
        clientStatsProvider.overrideWith(
          (ref) async => const ClientDashboardStats(
            activeJobsCount: 1,
            activeContractsCount: 2,
            completedContractsCount: 4,
            unreviewedProposalsCount: 3,
            monthlyCompleted: [0, 1, 1, 0, 2, 1],
          ),
        ),
        freelancerStatsProvider.overrideWith(
          (ref) async => const FreelancerDashboardStats(
            activeContractsCount: 2,
            completedContractsCount: 9,
            pendingProposalsCount: 3,
            sentProposalsCount: 18,
            acceptedProposalsCount: 7,
            monthlyCompleted: [1, 2, 1, 3, 1, 2],
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('painel do contratante tem um atalho por destino', (
    tester,
  ) async {
    await _pump(tester, UserRole.client, const ClientDashboardScreen());

    expect(tester.takeException(), isNull);
    expect(find.text('Painel do contratante'), findsOneWidget);
    expect(find.text('Buscar Talentos'), findsOneWidget);
    expect(find.text('Publicar Vaga'), findsOneWidget);
    expect(find.text('Explorar Profissionais Freelancer'), findsNothing);
    expect(find.byTooltip('Buscar Freelancers'), findsNothing);
    expect(find.byTooltip('Publicar Projeto'), findsNothing);

    await tester.tap(find.text('Propostas p/ analisar'));
    await tester.pumpAndSettle();
    expect(find.text('mural:Minhas Vagas'), findsOneWidget);
  });

  testWidgets('painel do freelancer leva às vagas e às conversas', (
    tester,
  ) async {
    await _pump(tester, UserRole.freelancer, const FreelancerDashboardScreen());

    expect(tester.takeException(), isNull);
    expect(find.text('Painel do freelancer'), findsOneWidget);
    expect(find.byTooltip('Planos'), findsNothing);

    await tester.tap(find.byKey(const Key('dashboard-find-jobs')));
    await tester.pumpAndSettle();
    expect(find.text('mural:null'), findsOneWidget);
  });

  testWidgets('contratos ativos abrem as mensagens', (tester) async {
    await _pump(tester, UserRole.freelancer, const FreelancerDashboardScreen());
    await tester.tap(find.text('Contratos ativos'));
    await tester.pumpAndSettle();
    expect(find.text('mensagens'), findsOneWidget);
  });
}
