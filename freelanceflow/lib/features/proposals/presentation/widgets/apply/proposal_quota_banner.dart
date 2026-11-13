import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../providers/proposals_provider.dart';

/// Saldo de propostas do mês e teto diário (somente para novos envios).
class ProposalQuotaBanner extends ConsumerWidget {
  final bool isEditing;

  const ProposalQuotaBanner({super.key, required this.isEditing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isEditing) return const SizedBox.shrink();
    final quota = ref.watch(proposalQuotaProvider).value;
    if (quota == null) return const SizedBox.shrink();

    final blocked = quota.isExhausted || quota.isDailyLimitReached;
    final color = blocked ? AppColors.error : AppColors.primaryLight;
    final String text;
    if (quota.isExhausted) {
      text = quota.isPro
          ? 'Você usou as ${quota.monthlyLimit} propostas do Pro neste mês. O saldo renova no dia 1º.'
          : 'Você usou as ${quota.monthlyLimit} propostas gratuitas deste mês.';
    } else if (quota.isDailyLimitReached) {
      text =
          'Você enviou ${quota.dailyLimit} propostas nas últimas 24 horas. '
          'Para manter a qualidade do mural, aguarde um pouco para enviar mais.';
    } else {
      text =
          'Propostas restantes este mês: ${quota.remaining} de ${quota.monthlyLimit}'
          '${quota.refunded > 0 ? ' (${quota.refunded} devolvida${quota.refunded > 1 ? 's' : ''})' : ''}.';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        children: [
          Icon(
            blocked
                ? Icons.lock_outline_rounded
                : Icons.local_activity_outlined,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Propostas para vagas canceladas, removidas pela moderação ou sem resposta do cliente voltam ao saldo.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMutedDark,
                  ),
                ),
              ],
            ),
          ),
          if (!quota.isPro)
            TextButton(
              onPressed: () => context.push('/plans'),
              child: const Text('Conhecer o Pro'),
            ),
        ],
      ),
    );
  }
}
