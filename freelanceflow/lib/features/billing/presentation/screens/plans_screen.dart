import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../domain/entities/billing.dart';
import '../../domain/entities/pricing.dart';
import '../providers/pricing_provider.dart';
import '../providers/billing_provider.dart';
import '../widgets/checkout_sheet.dart';
import '../widgets/pix_payment_sheet.dart';

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
    final subAsync = ref.watch(subscriptionProvider);
    final pricing = ref.watch(pricingProvider).valueOrNull ?? Pricing.fallback;
    final s = pricing.settings;
    final isPro = user?.isPro ?? false;
    final isClient = user?.role == UserRole.client;

    final freelancerPlans = [
      _PlanCard(
        title: 'Freelancer grátis',
        price: 'R\$ 0',
        highlighted: !isClient && !isPro,
        badge: !isClient && !isPro ? 'Seu plano' : null,
        features: [
          'Perfil e portfólio públicos',
          '${s.freeMonthlyProposals} propostas por mês',
          'Chat, contratos e entregas',
          'Arquivos de até ${s.freeFileMb} MB',
        ],
      ),
      const SizedBox(height: 16),
      _PlanCard(
        title: 'Freelancer Pro',
        price: '${CurrencyFormatter.format(pricing.pro.price)}/mês',
        highlighted: isPro,
        badge: isPro ? 'Seu plano' : null,
        features: [
          '${s.proMonthlyProposals} propostas por mês',
          'Modelos de proposta reutilizáveis',
          'Organização de clientes e projetos',
          'Estatísticas das suas propostas',
          'Arquivos de até ${s.proFileMb} MB',
          'Selo PRO, que indica a assinatura (não substitui avaliações)',
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
          data: (sub) => isClient
              ? const SizedBox.shrink()
              : _proFooter(user?.planExpiresAt, isPro, sub),
        ),
      ),
    ];

    final clientPlans = [
      _PlanCard(
        title: 'Cliente',
        price: 'Grátis',
        highlighted: isClient,
        badge: isClient ? 'Seu plano' : null,
        features: const [
          'Publicar projetos e receber propostas',
          'Conversar e negociar no chat',
          'Acompanhar entregas e aprovar marcos',
          'Avaliar o freelancer ao concluir',
        ],
      ),
      const SizedBox(height: 16),
      _PlanCard(
        title: 'Destaque de projeto',
        price:
            '${CurrencyFormatter.format(pricing.feature.price)} por ${pricing.feature.periodDays} dias',
        highlighted: false,
        features: [
          'Espaço no topo do mural, identificado como patrocinado',
          'Rodízio justo: até ${s.sponsoredSlots} vagas por vez; com mais, elas se revezam a cada ${_rotationText(s.sponsoredRotationMinutes)}',
          'Contratado na página da vaga, quando quiser',
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Planos')),
      body: ResponsiveLayout(
        maxWidth: 700,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pricingProvider);
            await refreshBillingState(ref);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Encontre profissionais e conduza o trabalho em um só lugar. '
                'O pagamento do projeto é direto entre as partes, sem comissão.',
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              // Quem contrata vê primeiro as opções de cliente.
              if (isClient) ...[
                const _SectionTitle('Para quem contrata'),
                ...clientPlans,
                const SizedBox(height: 28),
                const _SectionTitle('Para freelancers'),
                ...freelancerPlans,
              ] else ...[
                const _SectionTitle('Para freelancers'),
                ...freelancerPlans,
                const SizedBox(height: 28),
                const _SectionTitle('Para quem contrata'),
                ...clientPlans,
              ],
              const SizedBox(height: 24),
              _RulesCard(settings: s),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
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

String _rotationText(int minutes) => minutes % 60 == 0
    ? (minutes == 60 ? 'hora' : '${minutes ~/ 60} horas')
    : '$minutes minutos';

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.textMutedDark,
      ),
    ),
  );
}

/// Regras que valem para todos os planos, explicadas em linguagem simples.
class _RulesCard extends StatelessWidget {
  final PlatformSettings settings;
  const _RulesCard({required this.settings});

  @override
  Widget build(BuildContext context) {
    final rules = [
      'Propostas para vagas canceladas, removidas pela moderação ou sem resposta do cliente em ${settings.unansweredRefundDays} dias voltam ao seu saldo.',
      'Para evitar envio em massa, cada conta envia até ${settings.dailyProposals} propostas a cada 24 horas, em qualquer plano.',
      'A busca não favorece quem paga: a ordem considera compatibilidade, avaliações e trabalhos concluídos.',
      'O selo PRO mostra que a pessoa assina o plano. Confiança vem das avaliações e dos trabalhos concluídos.',
    ];
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Regras para todos',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 10),
          for (final r in rules)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppColors.textMutedDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
