import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/pricing.dart';
import '../../../domain/plan_benefits.dart';
import 'plan_card.dart';
import 'plan_comparison_table.dart';

/// Grátis × Pro para quem trabalha como freelancer.
class FreelancerPlansSection extends StatelessWidget {
  final Pricing pricing;
  final bool isPro;

  /// Situação da assinatura e botão de assinar/cancelar (nulo para
  /// contratantes, que não assinam o Pro).
  final Widget? proFooter;

  const FreelancerPlansSection({
    super.key,
    required this.pricing,
    required this.isPro,
    this.proFooter,
  });

  @override
  Widget build(BuildContext context) {
    final s = pricing.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlanPair(
          first: PlanCard(
            title: 'Grátis',
            subtitle: 'Para começar a receber trabalhos',
            price: CurrencyFormatter.format(0),
            priceNote: 'para sempre',
            badge: isPro ? null : 'Seu plano',
            features: freeBenefits(s),
          ),
          second: PlanCard(
            key: const Key('plans-pro-card'),
            title: 'Pro',
            subtitle: 'Para quem envia muitas propostas',
            price: CurrencyFormatter.format(pricing.pro.price),
            priceNote: 'por mês · cancele quando quiser',
            badge: isPro ? 'Seu plano' : 'Recomendado',
            highlighted: true,
            features: proBenefits(s),
            footer: proFooter,
          ),
        ),
        const SizedBox(height: 16),
        PlanComparisonTable(rows: planComparison(s)),
      ],
    );
  }
}

/// Contratar é grátis; o destaque patrocinado é opcional, por vaga.
class ClientPlansSection extends StatelessWidget {
  final Pricing pricing;
  final bool isClient;

  const ClientPlansSection({
    super.key,
    required this.pricing,
    required this.isClient,
  });

  @override
  Widget build(BuildContext context) {
    final feature = pricing.feature;
    return PlanPair(
      first: PlanCard(
        title: 'Contratar',
        subtitle: 'Tudo o que você precisa para contratar',
        price: 'Grátis',
        priceNote: 'sem mensalidade e sem comissão',
        badge: isClient ? 'Seu plano' : null,
        features: hiringBenefits(),
      ),
      second: PlanCard(
        key: const Key('plans-sponsored-card'),
        title: 'Destaque patrocinado',
        subtitle: 'Opcional, para uma vaga que precisa de mais olhos',
        price: CurrencyFormatter.format(feature.price),
        priceNote: 'por vaga, durante ${feature.periodDays} dias',
        features: sponsoredBenefits(pricing.settings),
        footer: isClient
            ? Padding(
                padding: const EdgeInsets.only(top: 16),
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/jobs', extra: 'Minhas Vagas'),
                  icon: const Icon(Icons.campaign_outlined, size: 18),
                  label: const Text('Escolher vaga para destacar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

/// Título e promessa geral da página.
class PlansIntro extends StatelessWidget {
  const PlansIntro({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Planos simples, sem comissão',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimaryDark,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Publicar vagas e trabalhar é grátis. O pagamento do trabalho é '
          'combinado e feito direto entre as partes.',
          style: TextStyle(color: AppColors.textSecondaryDark, height: 1.5),
        ),
      ],
    );
  }
}
