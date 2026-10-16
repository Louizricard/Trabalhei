import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freelanceflow/core/theme/app_colors.dart';
import 'package:freelanceflow/core/utils/currency_formatter.dart';
import 'package:freelanceflow/core/widgets/custom_button.dart';
import 'package:freelanceflow/core/widgets/glass_card.dart';
import 'package:freelanceflow/core/widgets/status_badge.dart';
import 'package:freelanceflow/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:freelanceflow/features/chat/domain/entities/conversation.dart';
import 'package:freelanceflow/features/chat/presentation/providers/chat_provider.dart';

import 'request_revision_modal.dart';
import 'review_contract_modal.dart';
import 'submit_deliverable_modal.dart';

class ContractMilestoneSheet extends ConsumerWidget {
  final Conversation conversation;

  const ContractMilestoneSheet({super.key, required this.conversation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveConv =
        ref.watch(conversationDetailProvider(conversation.id)).value ??
        conversation;
    final user = ref.watch(authProvider).value;
    final isClient = user?.id == liveConv.clientId;

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
                  'Marcos do Contrato',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              liveConv.jobTitle,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryDark,
              ),
            ),
            const SizedBox(height: 16),
            ...liveConv.milestones.map((m) {
              final hasDeliverables =
                  m.deliverableNotes != null && m.deliverableNotes!.isNotEmpty;
              final hasAttachments = m.deliverableAttachments.isNotEmpty;

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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimaryDark,
                              ),
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(m.amount),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (m.description.isNotEmpty) ...[
                        Text(
                          m.description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (hasDeliverables) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevatedDark,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderDark),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 14,
                                    color: AppColors.primaryLight,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    hasAttachments
                                        ? 'Entrega (${m.deliverableAttachments.length} anexo(s)):'
                                        : 'Entrega:',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryLight,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m.deliverableNotes!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryDark,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          _buildMilestoneBadge(m.status),
                          const Spacer(),
                          if ((m.status ==
                                      MilestoneStatus.pending ||
                                  m.status == MilestoneStatus.inRevision) &&
                              !isClient) ...[
                            CustomButton(
                              text: m.status == MilestoneStatus.inRevision
                                  ? 'Reenviar Entrega'
                                  : 'Entregar Marco',
                              icon: Icons.upload_file_rounded,
                              onPressed: () {
                                Navigator.of(context).pop();
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: AppColors.transparent,
                                  isScrollControlled: true,
                                  builder: (_) => SubmitDeliverableModal(
                                    conversation: liveConv,
                                    milestone: m,
                                  ),
                                );
                              },
                            ),
                          ] else if ((m.status == MilestoneStatus.submitted ||
                                  m.status == MilestoneStatus.inRevision) &&
                              isClient) ...[
                            CustomButton(
                              text: 'Revisar Entrega',
                              icon: Icons.check_circle_outline,
                              onPressed: () {
                                Navigator.of(context).pop();
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: AppColors.transparent,
                                  isScrollControlled: true,
                                  builder: (_) => RequestRevisionModal(
                                    conversation: liveConv,
                                    milestone: m,
                                  ),
                                );
                              },
                            ),
                          ] else if (m.status == MilestoneStatus.submitted &&
                              !isClient) ...[
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryLight,
                                side: const BorderSide(
                                  color: AppColors.borderDark,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 16,
                              ),
                              label: const Text(
                                'Ver Entrega',
                                style: TextStyle(fontSize: 12),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: AppColors.transparent,
                                  isScrollControlled: true,
                                  builder: (_) => RequestRevisionModal(
                                    conversation: liveConv,
                                    milestone: m,
                                  ),
                                );
                              },
                            ),
                          ] else if (m.status ==
                                  MilestoneStatus.approved &&
                              hasAttachments) ...[
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.success,
                                side: const BorderSide(
                                  color: AppColors.success,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(
                                Icons.download_done_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                'Baixar Arquivos',
                                style: TextStyle(fontSize: 12),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: AppColors.transparent,
                                  isScrollControlled: true,
                                  builder: (_) => RequestRevisionModal(
                                    conversation: liveConv,
                                    milestone: m,
                                  ),
                                );
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
            if (liveConv.milestones.any(
              (m) => m.status == MilestoneStatus.approved,
            )) ...[
              CustomButton(
                text: isClient ? 'Avaliar Profissional' : 'Avaliar Contratante',
                icon: Icons.star_rate_rounded,
                onPressed: () {
                  Navigator.of(context).pop();
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppColors.transparent,
                    isScrollControlled: true,
                    builder: (_) => ReviewContractModal(conversation: liveConv),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneBadge(MilestoneStatus status) {
    switch (status) {
      case MilestoneStatus.pending:
        return const StatusBadge(
          label: 'Em andamento',
          backgroundColor: AppColors.surfaceElevatedDark,
          textColor: AppColors.textMutedDark,
        );
      case MilestoneStatus.submitted:
        return const StatusBadge(
          label: 'Entregue p/ Revisão',
          backgroundColor: AppColors.infoBg,
          textColor: AppColors.info,
        );
      case MilestoneStatus.inRevision:
        return const StatusBadge(
          label: 'Revisão Solicitada',
          backgroundColor: AppColors.warningBg,
          textColor: AppColors.warning,
        );
      case MilestoneStatus.approved:
        return const StatusBadge(
          label: 'Aprovado',
          backgroundColor: AppColors.successBg,
          textColor: AppColors.success,
        );
    }
  }
}
