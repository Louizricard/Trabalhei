import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../domain/entities/pricing.dart';
import '../providers/pricing_provider.dart';
import '../providers/billing_provider.dart';
import '../widgets/checkout_sheet.dart';
import '../widgets/pix_payment_sheet.dart';
import '../widgets/plans/plan_rules.dart';
import '../widgets/plans/plan_sections.dart';
import '../widgets/plans/pro_subscription_footer.dart';

enum PlanAudience { freelancer, client }

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool _awaitingPayment = false;

  /// Perfil escolhido no seletor; nulo = segue o papel de quem está logado.
  PlanAudience? _audience;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Ao voltar do navegador (fatura do Asaas), recarrega o plano.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingPayment) {
      refreshBillingState(ref);
    }
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : AppColors.success,
      ),
    );
  }

  Future<void> _subscribe() async {
    final price = _pricing.pro.price;
    final data = await CheckoutSheet.show(
      context,
      title: 'Assinar Trabalhei Pro',
      summary:
          '${CurrencyFormatter.format(price)} por mês. Cancele quando quiser. '
          'Com cupom, o desconto vale para o primeiro mês.',
      product: 'pro_monthly',
      price: price,
      priceSuffix: 'por mês',
    );
    if (data == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await ref
          .read(billingRepositoryProvider)
          .startProCheckout(
            method: data.method,
            cpfCnpj: data.cpfCnpj,
            couponCode: data.couponCode,
          );
      if (!mounted) return;
      if (result.pix == null && !result.granted) {
        // Cartão: ao voltar da página do Asaas, o plano é recarregado.
        setState(() => _awaitingPayment = true);
      }
      await completeCheckout(
        context,
        result,
        successMessage:
            'Seu Pro está ativo. Aproveite as ferramentas no Painel.',
        isPaid: () async {
          await ref.read(authProvider.notifier).refreshProfile();
          return ref.read(authProvider).valueOrNull?.isPro ?? false;
        },
        onPaid: () => refreshBillingState(ref),
      );
    } catch (e) {
      _snack(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar assinatura?'),
        content: const Text(
          'Você mantém os benefícios do Pro até o fim do período já pago.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancelar assinatura'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(billingRepositoryProvider).cancelSubscription();
      await refreshBillingState(ref);
      _snack('Assinatura cancelada.');
    } catch (e) {
      _snack(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Pricing get _pricing =>
      ref.read(pricingProvider).valueOrNull ?? Pricing.fallback;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final pricing = ref.watch(pricingProvider).valueOrNull ?? Pricing.fallback;
    final isClient = user?.role == UserRole.client;
    final audience =
        _audience ?? (isClient ? PlanAudience.client : PlanAudience.freelancer);

    return Scaffold(
      appBar: AppBar(title: const Text('Planos')),
      body: ResponsiveLayout(
        maxWidth: 900,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pricingProvider);
            await refreshBillingState(ref);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const PlansIntro(),
              const SizedBox(height: 16),
              SegmentedButton<PlanAudience>(
                key: const Key('plans-audience'),
                segments: const [
                  ButtonSegment(
                    value: PlanAudience.freelancer,
                    icon: Icon(Icons.person_search_rounded),
                    label: Text('Sou freelancer'),
                  ),
                  ButtonSegment(
                    value: PlanAudience.client,
                    icon: Icon(Icons.business_center_outlined),
                    label: Text('Sou contratante'),
                  ),
                ],
                selected: {audience},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _audience = v.first),
              ),
              const SizedBox(height: 20),
              if (audience == PlanAudience.freelancer)
                FreelancerPlansSection(
                  pricing: pricing,
                  isPro: user?.isPro ?? false,
                  proFooter: isClient ? null : _proFooter(user),
                )
              else
                ClientPlansSection(pricing: pricing, isClient: isClient),
              const SizedBox(height: 24),
              PlanRulesAndFaq(pricing: pricing),
            ],
          ),
        ),
      ),
    );
  }

  Widget _proFooter(UserProfile? user) {
    return ref
        .watch(subscriptionProvider)
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              friendlyError(e),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
          data: (sub) => ProSubscriptionFooter(
            isPro: user?.isPro ?? false,
            expiresAt: user?.planExpiresAt,
            subscription: sub,
            busy: _busy,
            onSubscribe: _subscribe,
            onCancel: _cancel,
          ),
        );
  }
}
