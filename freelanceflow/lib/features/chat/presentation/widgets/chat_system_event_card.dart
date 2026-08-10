import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:freelanceflow/core/utils/currency_formatter.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import 'request_revision_modal.dart';
import 'review_contract_modal.dart';
import 'submit_deliverable_modal.dart';

class ChatSystemEventCard extends StatelessWidget {
  final ChatMessage msg;
  final Conversation? conversation;
  final dynamic currentUser;

  const ChatSystemEventCard({
    super.key,
    required this.msg,
    required this.conversation,
    required this.currentUser,
  });

  @override
Widget build(BuildContext context) {
    final conv = conversation;




    final isClient =
        (conv != null &&
            conv.clientId != null &&
            currentUser?.id == conv.clientId) ||
        (currentUser?.role == UserRole.client &&
            conv?.freelancerId != currentUser?.id);

    final isDelivery =
        msg.content.contains('Entrega') || msg.content.contains('📦');
    final isRevision =
        msg.content.contains('Revisão') ||
        msg.content.contains('🔄') ||
        msg.content.contains('Ajustes');
    final isApproved =
        msg.content.contains('aprovado') ||
        msg.content.contains('liberado') ||
        msg.content.contains('🎉');

    if (isDelivery &&
        conv != null &&
        conv.milestones.isNotEmpty) {
      final activeMilestone = conv.milestones.firstWhere(
        (m) =>
            m.status == MilestoneStatus.submitted ||
            m.status == MilestoneStatus.inRevision,
        orElse: () => conv.milestones.firstWhere(
          (m) => m.status == MilestoneStatus.fundedInEscrow,
          orElse: () => conv.milestones.first,
        ),
      );

      return Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 460),
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevatedDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primaryLight.withAlpha(90),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withAlpha(40),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      size: 20,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isClient
                              ? '📦 Entrega de Marco Recebida!'
                              : '📦 Entrega de Marco Enviada',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryLight,
                          ),
                        ),
                        Text(
                          activeMilestone.title,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(activeMilestone.amount),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(color: AppColors.borderDark, height: 1),
              ),
              Text(
                msg.content,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimaryDark,
                  height: 1.3,
                ),
              ),
              if (activeMilestone.deliverableAttachments.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.attach_file_rounded,
                      size: 16,
                      color: AppColors.primaryLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${activeMilestone.deliverableAttachments.length} anexo(s) incluído(s)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isClient
                        ? AppColors.success
                        : AppColors.primary,
                    foregroundColor: AppColors.pureWhite,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: Icon(
                    isClient
                        ? Icons.check_circle_outline_rounded
                        : Icons.visibility_outlined,
                    size: 18,
                  ),
                  label: Text(
                    isClient
                        ? 'Revisar Arquivos & Liberar Pagamento'
                        : 'Visualizar Detalhes da Entrega',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: AppColors.transparent,
                      isScrollControlled: true,
                      builder: (_) => RequestRevisionModal(
                        conversation: conv,
                        milestone: activeMilestone,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isRevision &&
        conv != null &&
        conv.milestones.isNotEmpty) {
      final activeMilestone = conv.milestones.firstWhere(
        (m) =>
            m.status == MilestoneStatus.inRevision ||
            m.status == MilestoneStatus.submitted,
        orElse: () => conv.milestones.first,
      );

      return Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 460),
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevatedDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.warning.withAlpha(100),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.warningBg,
                    child: const Icon(
                      Icons.replay_rounded,
                      size: 20,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isClient
                              ? '🔄 Revisão Solicitada'
                              : '⚠️ Ajustes Solicitados pelo Cliente',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                        ),
                        Text(
                          activeMilestone.title,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(color: AppColors.borderDark, height: 1),
              ),
              Text(
                msg.content,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimaryDark,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: isClient
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warning,
                          side: const BorderSide(color: AppColors.warning),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.info_outline_rounded, size: 18),
                        label: const Text(
                          'Ver Detalhes do Marco',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: AppColors.transparent,
                            isScrollControlled: true,
                            builder: (_) => RequestRevisionModal(
                              conversation: conv,
                              milestone: activeMilestone,
                            ),
                          );
                        },
                      )
                    : ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warning,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.upload_file_rounded, size: 18),
                        label: const Text(
                          'Reenviar Entrega Corrigida',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: AppColors.transparent,
                            isScrollControlled: true,
                            builder: (_) => SubmitDeliverableModal(
                              conversation: conv,
                              milestone: activeMilestone,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    }

    if (isApproved && conv != null) {
      return Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 460),
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevatedDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.success.withAlpha(100),
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.successBg,
                    child: Icon(
                      Icons.celebration_rounded,
                      size: 20,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '🎉 Pagamento Liberado com Sucesso!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(color: AppColors.borderDark, height: 1),
              ),
              Text(
                msg.content,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimaryDark,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              if (isClient) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.pureWhite,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.star_rate_rounded, size: 18),
                    label: const Text(
                      'Avaliar Freelancer',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: AppColors.transparent,
                        isScrollControlled: true,
                        builder: (_) =>
                            ReviewContractModal(conversation: conv),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Default System Message Chip
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevatedDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.security_rounded,
              size: 18,
              color: AppColors.primaryLight,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                msg.content,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimaryDark,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
