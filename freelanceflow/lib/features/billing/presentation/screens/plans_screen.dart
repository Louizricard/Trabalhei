import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../domain/entities/billing.dart';
import '../providers/billing_provider.dart';
import '../widgets/checkout_sheet.dart';

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool _awaitingPayment = false;

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
    final data = await CheckoutSheet.show(
      context,
      title: 'Assinar FreelanceFlow Pro',
      summary:
          '${CurrencyFormatter.format(BillingConfig.proMonthlyPrice)} por mês. '
          'Cancele quando quiser.',
    );
    if (data == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final url = await ref
          .read(billingRepositoryProvider)
          .startProCheckout(method: data.method, cpfCnpj: data.cpfCnpj);
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened) throw Exception('Não foi possível abrir a página de pagamento.');
      setState(() => _awaitingPayment = true);
      _snack('Conclua o pagamento na página aberta e volte ao app.');
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final subAsync = ref.watch(subscriptionProvider);
    final isPro = user?.isPro ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Planos')),
      body: ResponsiveLayout(
        maxWidth: 700,
        child: RefreshIndicator(
          onRefresh: () => refreshBillingState(ref),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _PlanCard(
                title: 'Grátis',
                price: 'R\$ 0',
                highlighted: !isPro,
                badge: !isPro ? 'Plano atual' : null,
                features: const [
                  '${BillingConfig.freeMonthlyProposals} propostas por mês',
                  'Chat, contratos e avaliações',
                  'Perfil e portfólio públicos',
                ],
              ),
              const SizedBox(height: 16),
              _PlanCard(
                title: 'Pro',
                price:
                    '${CurrencyFormatter.format(BillingConfig.proMonthlyPrice)}/mês',
                highlighted: isPro,
                badge: isPro ? 'Plano atual' : 'Recomendado',
                features: const [
                  'Propostas ilimitadas',
                  'Selo Pro no perfil e nas propostas',
                  'Mais visibilidade perante os clientes',
                ],
                footer: subAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      friendlyError(e),
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                  data: (sub) => _proFooter(user?.planExpiresAt, isPro, sub),
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.star_rounded, color: AppColors.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Cliente? Destaque suas vagas por '
                        '${BillingConfig.featureJobDays} dias direto na página '
                        'da vaga (${CurrencyFormatter.format(BillingConfig.featureJobPrice)}).',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _proFooter(DateTime? expiresAt, bool isPro, Subscription? sub) {
    final children = <Widget>[const SizedBox(height: 12)];

    if (isPro) {
      if (expiresAt != null) {
        children.add(
          Text(
            sub?.status == SubscriptionStatus.cancelled
                ? 'Cancelada — Pro ativo até ${DateFormatter.simpleDate(expiresAt)}.'
                : 'Pro ativo até ${DateFormatter.simpleDate(expiresAt)}.',
            style: const TextStyle(color: AppColors.success, fontSize: 13),
          ),
        );
      }
      if (sub != null &&
          sub.isOpen &&
          sub.status != SubscriptionStatus.cancelled) {
        children.addAll([
          const SizedBox(height: 12),
          CustomButton(
            text: 'Cancelar assinatura',
            variant: ButtonVariant.outline,
            width: double.infinity,
            isLoading: _busy,
            onPressed: _cancel,
          ),
        ]);
      }
    } else {
      if (sub != null && sub.status == SubscriptionStatus.pending) {
        children.add(
          const Text(
            'Pagamento pendente. Se já pagou, puxe a tela para atualizar.',
            style: TextStyle(color: AppColors.warning, fontSize: 13),
          ),
        );
        children.add(const SizedBox(height: 8));
      } else if (sub != null && sub.status == SubscriptionStatus.overdue) {
        children.add(
          const Text(
            'Pagamento em atraso. Regularize para manter o Pro.',
            style: TextStyle(color: AppColors.error, fontSize: 13),
          ),
        );
        children.add(const SizedBox(height: 8));
      }
      children.add(
        CustomButton(
          text: 'Assinar Pro',
          icon: Icons.workspace_premium_rounded,
          width: double.infinity,
          isLoading: _busy,
          onPressed: _subscribe,
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final bool highlighted;
  final String? badge;
  final List<String> features;
  final Widget? footer;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.highlighted,
    required this.features,
    this.badge,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted ? AppColors.primary : AppColors.borderDark,
          width: highlighted ? 1.6 : 1,
        ),
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const Spacer(),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryLight,
              ),
            ),
            const SizedBox(height: 12),
            for (final f in features)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ?footer,
          ],
        ),
      ),
    );
  }
}
