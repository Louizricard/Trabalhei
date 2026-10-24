import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/conversation.dart';

import 'package:trabalhei/core/utils/currency_formatter.dart';
import 'request_revision_modal.dart';
import 'review_contract_modal.dart';
import 'contract_milestone_sheet.dart';
import 'submit_deliverable_modal.dart';

class ChatDeliveryActionBanner extends StatelessWidget {
  final dynamic conversation;
  final dynamic currentUser;

  const ChatDeliveryActionBanner({
    super.key,
    required this.conversation,
    required this.currentUser,
  });

  @override
Widget build(BuildContext context) {
    final isClient = currentUser?.id == conversation.clientId;

    final milestones = List<ContractMilestone>.from(conversation.milestones);
    if (milestones.isEmpty) return const SizedBox.shrink();

    // Encontrar o marco em foco prioritário
    final activeMilestone = milestones.firstWhere(
      (m) =>
          m.status == MilestoneStatus.submitted ||
          m.status == MilestoneStatus.inRevision,
      orElse: () => milestones.firstWhere(
        (m) => m.status == MilestoneStatus.pending,
        orElse: () => milestones.first,
      ),
    );

    final allApproved = milestones.every(
      (m) => m.status == MilestoneStatus.approved,
    );

    // 1. Caso: Projeto 100% concluído
    if (allApproved) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.success.withAlpha(20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.success.withAlpha(80)),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.successBg,
              child: Icon(
                Icons.celebration_rounded,
                color: AppColors.success,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Projeto Concluído! 🎉',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.success,
                    ),
                  ),
                  Text(
                    'Todas as entregas foram aprovadas.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              icon: const Icon(Icons.star_rate_rounded, size: 16),
              label: const Text('Avaliar'),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: AppColors.transparent,
                  isScrollControlled: true,
                  builder: (_) =>
                      ReviewContractModal(conversation: conversation),
                );
              },
            ),
          ],
        ),
      );
    }

    // 2. Caso: Entrega enviada pelo Freelancer (Aguardando Aprovação)
    if (activeMilestone.status == MilestoneStatus.submitted) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primaryLight.withAlpha(100),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(40),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.surfaceElevatedDark,
              child: Icon(
                Icons.inventory_2_rounded,
                color: AppColors.primaryLight,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isClient ? '📦 Entrega Recebida!' : '⏳ Entrega Enviada',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        CurrencyFormatter.format(activeMilestone.amount),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    isClient
                        ? 'Analise os arquivos e aprove a entrega.'
                        : 'Aguardando o contratante analisar a entrega.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isClient
                    ? AppColors.success
                    : AppColors.primary,
                foregroundColor: AppColors.pureWhite,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              icon: Icon(
                isClient
                    ? Icons.check_circle_outline_rounded
                    : Icons.visibility_outlined,
                size: 16,
              ),
              label: Text(isClient ? 'Revisar & Aprovar' : 'Ver Entrega'),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: AppColors.transparent,
                  isScrollControlled: true,
                  builder: (_) => RequestRevisionModal(
                    conversation: conversation,
                    milestone: activeMilestone,
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    // 3. Caso: Revisão Solicitada pelo Cliente
    if (activeMilestone.status == MilestoneStatus.inRevision) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.warning.withAlpha(20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.warning.withAlpha(100),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.warningBg,
              child: Icon(
                Icons.replay_rounded,
                color: AppColors.warning,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isClient
                        ? '🔄 Revisão em Andamento'
                        : '⚠️ Ajustes Solicitados!',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.warning,
                    ),
                  ),
                  Text(
                    isClient
                        ? 'Você solicitou alterações no marco "${activeMilestone.title}".'
                        : 'O cliente solicitou correções. Faça os ajustes e reenvie.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!isClient)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: const Text('Reenviar'),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppColors.transparent,
                    isScrollControlled: true,
                    builder: (_) => SubmitDeliverableModal(
                      conversation: conversation,
                      milestone: activeMilestone,
                    ),
                  );
                },
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  side: const BorderSide(color: AppColors.warning),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.shield_outlined, size: 16),
                label: const Text('Ver Status', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppColors.transparent,
                    isScrollControlled: true,
                    builder: (_) =>
                        ContractMilestoneSheet(conversation: conversation),
                  );
                },
              ),
          ],
        ),
      );
    }

    // 4. Caso: Marco em andamento
    if (activeMilestone.status == MilestoneStatus.pending) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevatedDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.successBg,
              child: Icon(
                Icons.work_outline_rounded,
                color: AppColors.success,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Em andamento: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(activeMilestone.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    isClient
                        ? 'Acompanhe o andamento e aprove quando a entrega chegar.'
                        : 'Marco: ${activeMilestone.title}. Realize a entrega quando concluir.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!isClient)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: const Text('Entregar'),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppColors.transparent,
                    isScrollControlled: true,
                    builder: (_) => SubmitDeliverableModal(
                      conversation: conversation,
                      milestone: activeMilestone,
                    ),
                  );
                },
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryLight,
                  side: const BorderSide(color: AppColors.borderDark),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.shield_outlined, size: 16),
                label: const Text('Marcos', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppColors.transparent,
                    isScrollControlled: true,
                    builder: (_) =>
                        ContractMilestoneSheet(conversation: conversation),
                  );
                },
              ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
