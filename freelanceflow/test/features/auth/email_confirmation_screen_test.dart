import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/features/auth/presentation/screens/email_confirmation_screen.dart';

void main() {
  testWidgets('tela pós-cadastro explica a confirmação e cabe no celular', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: EmailConfirmationScreen(email: 'pessoa@exemplo.com'),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Confirme seu e-mail'), findsOneWidget);
    expect(
      find.textContaining('pessoa@exemplo.com', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Ir para o login'), findsOneWidget);
    expect(find.text('Reenviar e-mail'), findsOneWidget);
  });
}
