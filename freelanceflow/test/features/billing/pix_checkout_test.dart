import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/features/billing/domain/entities/checkout.dart';
import 'package:trabalhei/features/billing/presentation/widgets/pix_payment_sheet.dart';

void main() {
  test('Pix sem payload não cai silenciosamente na fatura do navegador', () {
    for (final pix in [
      null,
      <String, dynamic>{'payload': ''},
    ]) {
      expect(
        () => CheckoutResult.fromPaymentResponse({
          'invoice_url': 'https://example.invalid/invoice',
          'pix': pix,
        }, requiresPix: true),
        throwsA(isA<Exception>()),
      );
    }
    expect(
      CheckoutResult.fromPaymentResponse({
        'invoice_url': 'https://example.invalid/invoice',
      }, requiresPix: false).invoiceUrl,
      isNotNull,
    );
    expect(
      CheckoutResult.fromPaymentResponse({
        'granted': true,
      }, requiresPix: true).granted,
      isTrue,
    );
  });

  testWidgets('Pix mostra checkout no app, copia código e confirma pagamento', (
    tester,
  ) async {
    bool paid = false;
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: FilledButton(
                onPressed: () => completeCheckout(
                  context,
                  CheckoutResult.fromPaymentResponse({
                    'payment_id': 'pay_current',
                    'amount': 14.9,
                    'pix': {'image_base64': '', 'payload': 'test-copy-paste'},
                    'invoice_url': 'https://example.invalid/should-not-open',
                  }, requiresPix: true),
                  isPaid: () async => paid,
                  successMessage: 'Plano liberado',
                  onPaid: () async {},
                ),
                child: const Text('Pagar'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Pagar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PixPaymentSheet), findsOneWidget);
    expect(find.text('Copiar código Pix'), findsOneWidget);
    await tester.tap(find.text('Copiar código Pix'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(clipboard, 'test-copy-paste');
    paid = true;
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Pagamento confirmado'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.byType(PixPaymentSheet), findsNothing);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
}
