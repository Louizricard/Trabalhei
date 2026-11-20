import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/core/utils/currency_formatter.dart';
import 'package:trabalhei/features/auth/domain/entities/user_profile.dart';
import 'package:trabalhei/features/auth/domain/repositories/auth_repository.dart';
import 'package:trabalhei/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:trabalhei/features/billing/data/play_billing_service.dart';
import 'package:trabalhei/features/billing/domain/entities/pricing.dart';
import 'package:trabalhei/features/billing/presentation/providers/billing_provider.dart';
import 'package:trabalhei/features/billing/presentation/providers/pricing_provider.dart';
import 'package:trabalhei/features/billing/presentation/screens/plans_screen.dart';

/// Números propositalmente diferentes dos padrões: se algum texto da página
/// estiver fixo no código, o teste falha.
const _pricing = Pricing(
  pro: BillingProduct(
    code: 'pro_monthly',
    name: 'Pro',
    price: 29.90,
    periodDays: 30,
  ),
  feature: BillingProduct(
    code: 'job_feature',
    name: 'Destaque',
    price: 19.90,
    periodDays: 5,
  ),
  settings: PlatformSettings(
    freeMonthlyProposals: 7,
    proMonthlyProposals: 77,
    dailyProposals: 11,
    unansweredRefundDays: 9,
    sponsoredSlots: 3,
    sponsoredRotationMinutes: 120,
    freeFileMb: 13,
    proFileMb: 66,
    maxProposalTemplates: 33,
  ),
);

UserProfile _user(UserRole role, {bool pro = false}) => UserProfile(
  id: 'u1',
  plan: pro ? 'pro' : 'free',
  planExpiresAt: pro ? DateTime.now().add(const Duration(days: 20)) : null,
  email: 'pessoa@exemplo.com',
  fullName: 'Pessoa Teste',
  role: role,
  createdAt: DateTime(2026),
);

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

class _Play implements PlayBillingService {
  final List<String> bought = [];

  @override
  void start() {}

  @override
  Future<void> restore(String userId) async {}

  @override
  Future<PlayPurchaseEvent> buyPro({required String userId}) async {
    bought.add('pro:$userId');
    return const PlayPurchaseEvent(PlayProducts.pro, PlayOutcome.pending);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(
  WidgetTester tester,
  UserRole role,
  Size size, {
  _Play? play,
  bool playSubscription = false,
  bool pro = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_Repo(_user(role, pro: pro))),
        pricingProvider.overrideWith((ref) async => _pricing),
        subscriptionProvider.overrideWith((ref) async => null),
        playBillingEnabledProvider.overrideWithValue(play != null),
        if (play != null) playBillingProvider.overrideWithValue(play),
        playSubscriptionActiveProvider.overrideWith(
          (ref) async => playSubscription,
        ),
      ],
      child: const MaterialApp(home: PlansScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _text(String s) => find.textContaining(s, findRichText: true);

void main() {
  testWidgets('freelancer vê Grátis × Pro com os números do servidor', (
    tester,
  ) async {
    await _pump(tester, UserRole.freelancer, const Size(1000, 2400));

    expect(tester.takeException(), isNull);
    expect(_text('Sou freelancer'), findsOneWidget);
    expect(_text(CurrencyFormatter.format(29.90)), findsOneWidget);
    expect(_text('até 7 propostas por mês'), findsOneWidget);
    expect(_text('até 77 propostas por mês'), findsOneWidget);
    expect(_text('até 33 modelos de proposta'), findsOneWidget);
    expect(_text('arquivos de até 13 MB'), findsOneWidget);
    expect(_text('arquivos de até 66 MB'), findsOneWidget);
    expect(_text('até 11 propostas a cada 24 horas'), findsOneWidget);
    expect(_text('em 9 dias'), findsOneWidget);
    expect(find.byKey(const Key('plans-subscribe')), findsOneWidget);
    // Nenhum padrão antigo vazou para a tela.
    expect(_text('50 propostas'), findsNothing);
    expect(_text('10 MB'), findsNothing);
  });

  testWidgets('contratante abre no destaque com preço, dias e rodízio', (
    tester,
  ) async {
    await _pump(tester, UserRole.client, const Size(375, 2400));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('plans-sponsored-card')), findsOneWidget);
    expect(_text(CurrencyFormatter.format(19.90)), findsOneWidget);
    expect(_text('durante 5 dias'), findsOneWidget);
    expect(_text('Até 3 vagas patrocinadas'), findsOneWidget);
    expect(_text('a cada 2 horas'), findsOneWidget);
    expect(_text('Escolher vaga para destacar'), findsOneWidget);
    // Contratante não assina o Pro.
    expect(find.byKey(const Key('plans-subscribe')), findsNothing);

    await tester.tap(_text('Sou freelancer'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plans-pro-card')), findsOneWidget);
    expect(find.byKey(const Key('plans-subscribe')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FAQ usa os dias do destaque do servidor', (tester) async {
    await _pump(tester, UserRole.client, const Size(1000, 2400));
    await tester.tap(_text('Prazo urgente'));
    await tester.pumpAndSettle();
    expect(_text('topo do mural por 5 dias'), findsOneWidget);
  });

  testWidgets('Android: Pro é comprado pelo Google Play, sem Pix nem cupom', (
    tester,
  ) async {
    final play = _Play();
    await _pump(
      tester,
      UserRole.freelancer,
      const Size(1000, 2400),
      play: play,
    );

    await tester.tap(find.byKey(const Key('plans-subscribe')));
    await tester.pumpAndSettle();
    expect(play.bought, ['pro:u1']);
    expect(_text('Pagamento pendente no Google Play'), findsOneWidget);
    // A folha de checkout do Asaas (Pix/cartão/cupom) não abre no Android.
    expect(_text('CPF'), findsNothing);

    await tester.tap(_text('Como pago?'));
    await tester.pumpAndSettle();
    expect(_text('conta do Google Play'), findsOneWidget);
    expect(_text('Pix'), findsNothing);
  });

  testWidgets('Android: assinante do Google Play gerencia pelo Google Play', (
    tester,
  ) async {
    await _pump(
      tester,
      UserRole.freelancer,
      const Size(1000, 2400),
      play: _Play(),
      playSubscription: true,
      pro: true,
    );
    expect(find.byKey(const Key('plans-manage-play')), findsOneWidget);
    expect(find.byKey(const Key('plans-subscribe')), findsNothing);
    // Cancelar pelo app (Asaas) não aparece para assinatura do Google.
    expect(_text('Cancelar assinatura'), findsNothing);
  });
}
