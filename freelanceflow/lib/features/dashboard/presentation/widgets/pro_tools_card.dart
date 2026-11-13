import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../billing/presentation/widgets/pro_upsell.dart';
import '../screens/pro_tools_screens.dart';

/// Ferramentas do plano Pro. No grátis, o toque explica o recurso e leva aos
/// planos.
class ProToolsCard extends StatelessWidget {
  final bool isPro;
  const ProToolsCard({super.key, required this.isPro});

  @override
  Widget build(BuildContext context) {
    final tools = [
      (
        Icons.insights_rounded,
        'Estatísticas das propostas',
        'Aceite, tempo de resposta e valores',
        '/pro/stats',
        statsUpsell,
      ),
      (
        Icons.groups_2_outlined,
        'Clientes e projetos',
        'Histórico e anotações por cliente',
        '/pro/clients',
        clientsUpsell,
      ),
      (
        Icons.content_paste_rounded,
        'Modelos de proposta',
        'Cartas e prazos prontos para reutilizar',
        '/pro/templates',
        'Salve cartas de apresentação e prazos que você usa sempre e aplique em um toque.',
      ),
    ];
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 16, 4),
            child: Row(
              children: [
                const Text(
                  'Ferramentas Pro',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(width: 8),
                if (!isPro) const ProBadge(),
              ],
            ),
          ),
          for (final t in tools)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Icon(t.$1, color: AppColors.primary),
              title: Text(t.$2),
              subtitle: Text(t.$3),
              trailing: Icon(
                isPro
                    ? Icons.chevron_right_rounded
                    : Icons.lock_outline_rounded,
                color: AppColors.textMutedDark,
              ),
              onTap: () => isPro
                  ? context.push(t.$4)
                  : showProUpsell(context, feature: t.$2, description: t.$5),
            ),
        ],
      ),
    );
  }
}
