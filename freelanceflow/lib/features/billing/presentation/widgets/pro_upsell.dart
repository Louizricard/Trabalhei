import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';

/// Aviso de recurso do plano Pro para quem está no grátis, com o caminho para
/// os planos. [feature] descreve o recurso ("Modelos de proposta").
Future<void> showProUpsell(
  BuildContext context, {
  required String feature,
  required String description,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(
        Icons.workspace_premium_rounded,
        color: AppColors.primary,
      ),
      title: Text('$feature é do plano Pro'),
      content: Text(description),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Agora não'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            context.push('/plans');
          },
          child: const Text('Ver o Pro'),
        ),
      ],
    ),
  );
}

/// Cartão de recurso Pro bloqueado, para telas que mostram uma prévia.
class ProLockedCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const ProLockedCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const ProBadge(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => context.push('/plans'),
                  child: const Text('Conhecer o Pro'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Selo de assinatura Pro. Discreto e neutro de propósito: indica que a pessoa
/// assina o plano, não que é mais qualificada. Confiança vem das avaliações e
/// dos trabalhos concluídos, mostrados ao lado.
class ProBadge extends StatelessWidget {
  const ProBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Assinante do plano Pro. Não indica avaliação nem experiência.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: const Text(
          'PRO',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: AppColors.textSecondaryDark,
          ),
        ),
      ),
    );
  }
}
