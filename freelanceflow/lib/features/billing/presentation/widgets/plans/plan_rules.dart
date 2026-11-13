import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../domain/entities/pricing.dart';
import '../../../domain/plan_benefits.dart';

/// Regras que valem para todos os planos e perguntas frequentes.
class PlanRulesAndFaq extends StatelessWidget {
  final Pricing pricing;

  const PlanRulesAndFaq({super.key, required this.pricing});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Heading('Regras para todos'),
              for (final r in planRules(pricing.settings)) _Rule(r),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: _Heading('Perguntas frequentes'),
              ),
              for (final (q, a) in planFaq(pricing))
                ExpansionTile(
                  title: Text(q, style: const TextStyle(fontSize: 14)),
                  childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                  expandedAlignment: Alignment.centerLeft,
                  shape: const Border(),
                  children: [
                    Text(
                      a,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
    ),
  );
}

class _Rule extends StatelessWidget {
  final String text;
  const _Rule(this.text);

  @override
  Widget build(BuildContext context) => Padding(
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
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondaryDark,
            ),
          ),
        ),
      ],
    ),
  );
}
