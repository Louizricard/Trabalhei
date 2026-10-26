import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/features/auth/domain/entities/user_profile.dart';
import 'package:trabalhei/features/billing/domain/entities/billing.dart';
import 'package:trabalhei/features/billing/domain/entities/checkout.dart';
import 'package:trabalhei/features/billing/domain/entities/pricing.dart';
import 'package:trabalhei/features/billing/presentation/widgets/checkout_sheet.dart';

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
    Future<CheckoutData?> Function() openSheet(WidgetTester tester) {
      CheckoutData? result;
      return () async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        result = await CheckoutSheet.show(
                          context,
                          title: 'Assinar Pro',
                          summary: 'R\$ 14,90 por mês',
                          product: 'pro_monthly',
                          price: 14.90,
                          priceSuffix: 'por mês',
                        );
                      },
                      child: const Text('abrir'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
        return result;
      };
    }

    testWidgets('rejeita documento com tamanho inválido', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openSheet(tester)();
      await tester.enterText(find.byType(TextFormField), '123');
      await tester.tap(find.textContaining('Gerar Pix'));
      await tester.pumpAndSettle();
      expect(find.textContaining('CPF (11 dígitos)'), findsOneWidget);
    });

    testWidgets('Pix é o padrão e o cartão abre a página segura', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      CheckoutData? result;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await CheckoutSheet.show(
                      context,
                      title: 't',
                      summary: 's',
                      product: 'job_feature',
                      price: 9.90,
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
      expect(find.textContaining('Gerar Pix de'), findsOneWidget);

      await tester.tap(find.text('Cartão de crédito'));
      await tester.pumpAndSettle();
      expect(find.textContaining('com cartão'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '123.456.789-09');
      await tester.tap(find.textContaining('com cartão'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.method, BillingMethod.creditCard);
      expect(result!.cpfCnpj, '12345678909');
      expect(result!.couponCode, isNull);
      expect(result!.quote.finalPrice, 9.90);
    });
  });

  group('Checkout', () {
    test('cupom de 100% libera sem cobrança', () {
      final r = CheckoutResult.fromJson({'granted': true});
      expect(r.granted, isTrue);
      expect(r.pix, isNull);
    });

    test('Pix traz QR Code e código copia e cola', () {
      final r = CheckoutResult.fromJson({
        'payment_id': 'pay_1',
        'amount': 7.45,
        'pix': {
          'image_base64': 'aGVsbG8=',
          'payload': '00020126...',
          'expires_at': '2026-10-28 23:59:59',
        },
      });
      expect(r.amount, 7.45);
      expect(r.pix!.payload, startsWith('0002'));
      expect(r.pix!.expiresAt, isNotNull);
    });

    test('preço com cupom', () {
      final q = PriceQuote.fromJson({
        'price': 14.9,
        'final_price': 7.45,
        'discount': 7.45,
        'code': 'LANCAMENTO50',
      });
      expect(q.isFree, isFalse);
      expect(q.code, 'LANCAMENTO50');
      expect(
        PriceQuote.fromJson({'price': 9.9, 'final_price': 0}).isFree,
        isTrue,
      );
    });
  });

  group('Pricing', () {
    test('lê limites do banco e calcula o tamanho de arquivo por plano', () {
      final s = PlatformSettings.fromJson({
        'free_monthly_proposals': 10,
        'pro_monthly_proposals': 50,
        'free_file_mb': 10,
        'pro_file_mb': 50,
      });
      expect(s.proMonthlyProposals, 50);
      expect(s.fileLimitBytes(isPro: false), 10 * 1024 * 1024);
      expect(s.fileLimitBytes(isPro: true), 50 * 1024 * 1024);
      expect(Pricing.fallback.pro.price, 14.90);
      expect(Pricing.fallback.feature.price, 9.90);
    });
  });
}
