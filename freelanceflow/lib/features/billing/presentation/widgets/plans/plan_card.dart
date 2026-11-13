import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/glass_card.dart';

/// Cartão de um plano ou produto: nome, preço em destaque, benefícios e
/// ação. [highlighted] usa a borda mint (sem gradiente) para o recomendado.
class PlanCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final String? priceNote;
  final String? badge;
  final bool highlighted;
  final List<String> features;
  final Widget? footer;

  const PlanCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.price,
    this.priceNote,
    this.badge,
    this.highlighted = false,
    required this.features,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted ? AppColors.primary : AppColors.borderDark,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryDark,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              price,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimaryDark,
              ),
            ),
            if (priceNote != null)
              Text(
                priceNote!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMutedDark,
                ),
              ),
            const SizedBox(height: 16),
            for (final f in features) PlanFeature(f),
            ?footer,
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryDark,
            ),
          ),
        ),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: highlighted
                  ? AppColors.primary
                  : AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: highlighted ? AppColors.onPrimary : AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

/// Linha de benefício com marcador.
class PlanFeature extends StatelessWidget {
  final String text;

  const PlanFeature(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                color: AppColors.textPrimaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dois cartões lado a lado em telas largas; empilhados no celular.
class PlanPair extends StatelessWidget {
  final Widget first;
  final Widget second;

  const PlanPair({super.key, required this.first, required this.second});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth < 600
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [first, const SizedBox(height: 16), second],
            )
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: first),
                  const SizedBox(width: 16),
                  Expanded(child: second),
                ],
              ),
            ),
    );
  }
}
