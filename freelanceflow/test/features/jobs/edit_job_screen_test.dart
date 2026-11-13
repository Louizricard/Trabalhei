import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/features/billing/presentation/providers/pricing_provider.dart';
import 'package:trabalhei/features/jobs/domain/entities/job.dart';
import 'package:trabalhei/features/jobs/presentation/screens/create_job_screen.dart';

final _job = Job(
  id: 'j1',
  clientId: 'c1',
  clientName: 'Cliente',
  title: 'App de delivery para restaurante',
  // Vaga anterior ao catálogo: "Mobile" vira Tecnologia › Mobile.
  category: 'Mobile',
  description: 'Aplicativo com cardápio, carrinho e pagamento na entrega.',
  budgetMin: 1500,
  budgetMax: 3000,
  skillsRequired: const ['Flutter'],
  attachments: const [
    {'id': 'a1', 'name': 'briefing.pdf', 'url': 'https://x/briefing.pdf'},
  ],
  createdAt: DateTime(2026),
);

void main() {
  testWidgets('editar vaga mostra anexos salvos, área e Salvar Alterações', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [uploadLimitBytesProvider.overrideWithValue(10 << 20)],
        child: MaterialApp(home: CreateJobScreen(jobToEdit: _job)),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Editar vaga'), findsOneWidget);
    expect(find.text('Tecnologia'), findsOneWidget);
    final form = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('briefing.pdf'),
      300,
      scrollable: form,
    );
    expect(find.text('Prazo urgente'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Salvar Alterações'),
      300,
      scrollable: form,
    );
    expect(tester.takeException(), isNull);

    // Remover um anexo salvo libera vaga no limite total.
    await tester.tap(find.byTooltip('Remover briefing.pdf'));
    await tester.pump();
    expect(find.text('briefing.pdf'), findsNothing);
  });

  testWidgets('nova vaga não vem com categoria escolhida', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [uploadLimitBytesProvider.overrideWithValue(10 << 20)],
        child: const MaterialApp(home: CreateJobScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Escolha ou busque uma área'), findsOneWidget);
    expect(find.text('Publicar vaga'), findsWidgets);
  });
}
