import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:trabalhei/features/admin/domain/admin_models.dart';
import 'package:trabalhei/features/admin/presentation/providers/admin_provider.dart';
import 'package:trabalhei/features/admin/presentation/screens/admin_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  Widget app({required bool isAdmin}) => ProviderScope(
    overrides: [
      isAdminProvider.overrideWith((ref) async => isAdmin),
      adminOverviewProvider.overrideWith(
        (ref) async => const AdminOverview(
          users: 13,
          suspended: 1,
          openJobs: 4,
          openReports: 2,
        ),
      ),
      adminReportsProvider.overrideWith(
        (ref, status) async => [
          AdminReport(
            id: 'r1',
            target: ReportTarget.job,
            targetId: 'j1',
            targetLabel: 'Logo para padaria',
            reason: ReportReason.fraud,
            details: 'Pediu pagamento adiantado por fora.',
            status: status,
            createdAt: DateTime(2026, 10, 26),
            reporterName: 'Ana',
            reportsOnTarget: 2,
          ),
        ],
      ),
      adminUsersProvider.overrideWith(
        (ref, query) async => [
          AdminUser(
            id: 'u1',
            fullName: 'Bruno',
            email: 'bruno@exemplo.com',
            role: 'client',
            plan: 'free',
            createdAt: DateTime(2026, 10, 1),
            suspendedAt: DateTime(2026, 10, 25),
          ),
        ],
      ),
    ],
    child: const MaterialApp(home: AdminScreen()),
  );

  testWidgets('administrador vê o resumo e as denúncias com ações', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(isAdmin: true));
    await tester.pumpAndSettle();

    expect(find.text('Denúncias (2)'), findsOneWidget);
    expect(find.text('Vaga: Logo para padaria'), findsOneWidget);
    expect(find.text('Golpe ou fraude'), findsOneWidget);
    expect(find.text('2 denúncias'), findsOneWidget);
    expect(find.text('Remover vaga'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(Tab, 'Usuários'));
    await tester.pumpAndSettle();
    expect(find.text('bruno@exemplo.com'), findsOneWidget);
    expect(find.text('Suspensa'), findsOneWidget);
    expect(find.text('Reativar'), findsOneWidget);
  });

  testWidgets('quem não é administrador vê acesso restrito', (tester) async {
    await tester.pumpWidget(app(isAdmin: false));
    await tester.pumpAndSettle();
    expect(find.text('Acesso restrito'), findsOneWidget);
    expect(find.text('Denúncias (2)'), findsNothing);
  });
}
