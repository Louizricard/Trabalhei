import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freelanceflow/features/auth/domain/entities/user_profile.dart';
import 'package:freelanceflow/features/billing/domain/entities/billing.dart';
import 'package:freelanceflow/features/billing/presentation/widgets/checkout_sheet.dart';

UserProfile _user({String plan = 'free', DateTime? expires}) => UserProfile(
  id: 'u1',
  email: 'a@b.com',
  fullName: 'Ana',
  role: UserRole.freelancer,
  plan: plan,
  planExpiresAt: expires,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  group('Subscription', () {
    test('interpreta o JSON da tabela subscriptions', () {
      final sub = Subscription.fromJson({
        'id': 's1',
        'status': 'active',
        'billing_type': 'CREDIT_CARD',
        'current_period_end': '2026-12-01T00:00:00Z',
        'created_at': '2026-11-01T00:00:00Z',
      });
      expect(sub.status, SubscriptionStatus.active);
      expect(sub.method, BillingMethod.creditCard);
      expect(sub.isOpen, isTrue);
      expect(sub.currentPeriodEnd, isNotNull);
    });

    test('assinatura cancelada não está em aberto', () {
      final sub = Subscription.fromJson({
        'id': 's2',
        'status': 'cancelled',
        'billing_type': 'PIX',
        'created_at': '2026-11-01T00:00:00Z',
      });
      expect(sub.isOpen, isFalse);
      expect(sub.method, BillingMethod.pix);
    });

    test('status desconhecido cai em pendente', () {
      expect(SubscriptionStatus.parse('xyz'), SubscriptionStatus.pending);
    });
  });

  group('UserProfile.isPro', () {
    test('plano grátis não é Pro', () {
      expect(_user().isPro, isFalse);
    });

    test('Pro sem expiração é Pro', () {
      expect(_user(plan: 'pro').isPro, isTrue);
    });

    test('Pro vencido deixa de valer', () {
      final expired = DateTime.now().subtract(const Duration(days: 1));
      expect(_user(plan: 'pro', expires: expired).isPro, isFalse);
    });

    test('Pro com validade futura vale', () {
      final future = DateTime.now().add(const Duration(days: 10));
      expect(_user(plan: 'pro', expires: future).isPro, isTrue);
    });

    test('perfil lido do servidor traz plano e não traz dados financeiros', () {
      final profile = UserProfile.fromJson({
        'id': 'u1',
        'full_name': 'Ana',
        'role': 'freelancer',
        'plan': 'pro',
        'plan_expires_at': DateTime.now()
            .add(const Duration(days: 5))
            .toIso8601String(),
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(profile.isPro, isTrue);
      expect(profile.toUpdateJson().containsKey('plan'), isFalse);
      expect(profile.toUpdateJson().containsKey('rating'), isFalse);
    });
  });

  group('CheckoutSheet', () {
    Future<CheckoutData?> openSheet(
      WidgetTester tester, {
      bool askMethod = true,
    }) async {
      CheckoutData? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await CheckoutSheet.show(
                      context,
                      title: 'Assinar Pro',
                      summary: 'R\$ 29,90 por mês',
                      askMethod: askMethod,
                    );
                  },
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('rejeita documento com tamanho inválido', (tester) async {
      await openSheet(tester);
      await tester.enterText(find.byType(TextFormField), '123');
      await tester.tap(find.text('Continuar para o pagamento'));
      await tester.pumpAndSettle();
      expect(find.textContaining('CPF (11 dígitos)'), findsOneWidget);
    });

    testWidgets('devolve forma de pagamento e documento só com dígitos', (
      tester,
    ) async {
      CheckoutData? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await CheckoutSheet.show(
                    context,
                    title: 't',
                    summary: 's',
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cartão de crédito'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '123.456.789-09');
      await tester.tap(find.text('Continuar para o pagamento'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.method, BillingMethod.creditCard);
      expect(result!.cpfCnpj, '12345678909');
    });

    testWidgets('oculta a escolha de método quando askMethod é falso', (
      tester,
    ) async {
      await openSheet(tester, askMethod: false);
      expect(find.text('Pix'), findsNothing);
    });
  });
}
