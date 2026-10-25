import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabalhei/features/auth/presentation/providers/pending_confirmation_provider.dart';
import 'package:trabalhei/features/auth/presentation/widgets/pending_confirmation_banner.dart';

void main() {
  group('PendingConfirmationNotifier', () {
    test('recupera o e-mail salvo ao abrir o app', () async {
      SharedPreferences.setMockInitialValues({
        'pending_confirmation_email': 'pessoa@exemplo.com',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(pendingConfirmationProvider);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(pendingConfirmationProvider), 'pessoa@exemplo.com');
    });

    test('salva e limpa o e-mail pendente', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(pendingConfirmationProvider.notifier);

      await notifier.set('nova@exemplo.com');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pending_confirmation_email'), 'nova@exemplo.com');

      await notifier.clear();
      expect(container.read(pendingConfirmationProvider), isNull);
      expect(prefs.getString('pending_confirmation_email'), isNull);
    });
  });

  group('PendingConfirmationBanner', () {
    Future<void> pumpBanner(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: PendingConfirmationBanner())),
        ),
      );
      await tester.pump();
    }

    testWidgets('não aparece sem cadastro pendente', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpBanner(tester);

      expect(find.text('Confirme seu e-mail'), findsNothing);
    });

    testWidgets('fica visível até o usuário trocar de e-mail', (tester) async {
      SharedPreferences.setMockInitialValues({
        'pending_confirmation_email': 'pessoa@exemplo.com',
      });
      await pumpBanner(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Confirme seu e-mail'), findsOneWidget);
      expect(
        find.textContaining('pessoa@exemplo.com', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Reenviar e-mail'), findsOneWidget);

      await tester.tap(find.text('Usar outro e-mail'));
      await tester.pump();

      expect(find.text('Confirme seu e-mail'), findsNothing);
    });
  });
}
