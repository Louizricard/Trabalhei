import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freelanceflow/core/theme/app_colors.dart';
import 'package:freelanceflow/core/utils/currency_formatter.dart';
import 'package:freelanceflow/core/widgets/custom_button.dart';
import 'package:freelanceflow/core/widgets/glass_card.dart';
import 'package:freelanceflow/core/widgets/status_badge.dart';
import 'package:freelanceflow/features/auth/domain/entities/user_profile.dart';
import 'package:freelanceflow/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:freelanceflow/features/chat/domain/entities/conversation.dart';
import 'package:freelanceflow/features/chat/presentation/providers/chat_provider.dart';

import 'review_contract_modal.dart';

class ContractMilestoneSheet extends ConsumerWidget {
  final Conversation conversation;

  const ContractMilestoneSheet({super.key, required this.conversation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final isClient = user?.role == UserRole.client;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Marcos do Contrato & Escrow',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              conversation.jobTitle,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryDark),
            ),
            const SizedBox(height: 16),
            ...conversation.milestones.map((m) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              m.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimaryDark),
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(m.amount),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.success),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (m.description.isNotEmpty) ...[
                        Text(m.description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark)),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          _buildMilestoneBadge(m.status),
                          const Spacer(),
                          if (m.status == MilestoneStatus.fundedInEscrow && !isClient) ...[
                            CustomButton(
                              text: 'Entregar para Revisão',
                              icon: Icons.upload_file_rounded,
                              onPressed: () {
                                ref.read(chatRepositoryProvider).updateMilestoneStatus(
                                      conversation.id,
                                      m.id,
                                      MilestoneStatus.submitted,
                                    );
                                Navigator.of(context).pop();
                              },
                            ),
                          ] else if (m.status == MilestoneStatus.submitted && isClient) ...[
                            CustomButton(
                              text: 'Aprovar e Liberar',
                              icon: Icons.check_circle_outline,
                              onPressed: () {
                                ref.read(chatRepositoryProvider).updateMilestoneStatus(
                                      conversation.id,
                                      m.id,
                                      MilestoneStatus.approvedAndReleased,
                                    );
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            if (conversation.milestones.any((m) => m.status == MilestoneStatus.approvedAndReleased)) ...[
              CustomButton(
                text: 'Avaliar Profissional',
                icon: Icons.star_rate_rounded,
                onPressed: () {
                  Navigator.of(context).pop();
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => ReviewContractModal(conversation: conversation),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.shield_outlined, size: 18),
              label: const Text('Abrir Mediação / Disputa'),
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Equipe de mediação do FreelanceFlow acionada com sucesso.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneBadge(MilestoneStatus status) {
    switch (status) {
      case MilestoneStatus.fundedInEscrow:
        return StatusBadge.escrowHold();
      case MilestoneStatus.submitted:
        return const StatusBadge(label: 'Entregue p/ Revisão', backgroundColor: AppColors.infoBg, textColor: AppColors.info);
      case MilestoneStatus.approvedAndReleased:
        return const StatusBadge(label: 'Aprovado e Pago', backgroundColor: AppColors.successBg, textColor: AppColors.success);
      case MilestoneStatus.disputed:
        return const StatusBadge(label: 'Em Disputa', backgroundColor: AppColors.errorBg, textColor: AppColors.error);
      default:
        return const StatusBadge(label: 'Aguardando Depósito', backgroundColor: AppColors.surfaceElevatedDark, textColor: AppColors.textMutedDark);
    }
  }
}
