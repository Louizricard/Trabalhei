import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/attachment_widgets.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../domain/entities/conversation.dart';
import '../providers/chat_provider.dart';

class RequestRevisionModal extends ConsumerStatefulWidget {
  final Conversation conversation;
  final ContractMilestone milestone;

  const RequestRevisionModal({
    super.key,
    required this.conversation,
    required this.milestone,
  });

  @override
  ConsumerState<RequestRevisionModal> createState() => _RequestRevisionModalState();
}

class _RequestRevisionModalState extends ConsumerState<RequestRevisionModal> {
  final _commentController = TextEditingController();
  List<PickedFileData> _selectedFiles = [];
  bool _isRequestingRevision = false;
  bool _isApproving = false;
  bool _showRevisionForm = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _approveAndRelease() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Aprovar e Liberar Pagamento?'),
        content: Text(
          'Você confirma que a entrega do marco "${widget.milestone.title}" atende aos requisitos acordados?\n\n'
          'O valor de ${CurrencyFormatter.format(widget.milestone.amount)} será liberado imediatamente do Escrow para a carteira do Freelancer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondaryDark)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sim, Liberar Pagamento'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isApproving = true);

    try {
      await ref.read(chatRepositoryProvider).updateMilestoneStatus(
            widget.conversation.id,
            widget.milestone.id,
            MilestoneStatus.approvedAndReleased,
          );

      ref.invalidate(conversationDetailProvider(widget.conversation.id));
      ref.invalidate(conversationsListProvider);
      ref.invalidate(clientStatsProvider);
      ref.invalidate(freelancerStatsProvider);
      ref.invalidate(authProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Pagamento liberado com sucesso ao Freelancer!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isApproving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao liberar pagamento: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _submitRevision() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe as observações e alterações solicitadas.')),
      );
      return;
    }

    setState(() => _isRequestingRevision = true);

    try {
      final storage = ref.read(storageServiceProvider);
      final uploadedAttachments = <Map<String, dynamic>>[];

      for (final file in _selectedFiles) {
        final result = await storage.uploadFile(
          bucket: 'chat_attachments',
          folder: 'revisions/${widget.milestone.id}',
          file: file,
        );
        if (result != null) {
          uploadedAttachments.add(result.toJson());
        }
      }

      await ref.read(chatRepositoryProvider).requestMilestoneRevision(
            conversationId: widget.conversation.id,
            milestoneId: widget.milestone.id,
            contractId: widget.milestone.contractId,
            comment: text,
            attachments: uploadedAttachments,
          );

      ref.invalidate(conversationDetailProvider(widget.conversation.id));
      ref.invalidate(conversationsListProvider);
      ref.invalidate(clientStatsProvider);
      ref.invalidate(freelancerStatsProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitação de revisão enviada ao freelancer.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRequestingRevision = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao solicitar revisão: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final isClient = (widget.conversation.clientId != null && user?.id == widget.conversation.clientId) ||
        (user?.role == UserRole.client && widget.conversation.freelancerId != user?.id);
    final isApproved = widget.milestone.status == MilestoneStatus.approvedAndReleased;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
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
                Expanded(
                  child: Text(
                    'Entrega: ${widget.milestone.title}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text(
                  'Valor do Marco: ',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondaryDark),
                ),
                Text(
                  CurrencyFormatter.format(widget.milestone.amount),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.success),
                ),
                const Spacer(),
                if (isApproved)
                  const Text(
                    '✅ Aprovado & Pago',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.milestone.deliverableNotes != null && widget.milestone.deliverableNotes!.isNotEmpty) ...[
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.primaryLight),
                        SizedBox(width: 8),
                        Text('Instruções e Observações da Entrega:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimaryDark)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.milestone.deliverableNotes!,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryDark, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.milestone.deliverableAttachments.isNotEmpty) ...[
              AttachmentCardsList(
                attachments: widget.milestone.deliverableAttachments,
                title: 'Arquivos Entregues pelo Freelancer',
              ),
              const SizedBox(height: 16),
            ],
            if (isApproved) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withAlpha(80)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Esta entrega foi aprovada e o valor foi creditado na carteira do Freelancer.',
                        style: TextStyle(fontSize: 12, color: AppColors.textPrimaryDark, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ] else if (isClient) ...[
              if (!_showRevisionForm) ...[
                CustomButton(
                  text: 'Aprovar Entrega & Liberar Pagamento',
                  icon: Icons.check_circle_outline_rounded,
                  isLoading: _isApproving,
                  width: double.infinity,
                  onPressed: _approveAndRelease,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: const BorderSide(color: AppColors.warning),
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Solicitar Ajustes / Revisão'),
                  onPressed: () => setState(() => _showRevisionForm = true),
                ),
              ] else ...[
                const Divider(color: AppColors.borderDark, height: 24),
                const Text(
                  'O que precisa ser corrigido ou ajustado?',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _commentController,
                  label: 'Instruções de Ajuste',
                  hint: 'Descreva detalhadamente o que deve ser revisado...',
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                AttachmentPickerSection(
                  selectedFiles: _selectedFiles,
                  onChanged: (files) => setState(() => _selectedFiles = files),
                  title: 'Prints / Exemplos de Referência (Opcional)',
                  hintText: 'Anexe capturas ou documentos apontando o que ajustar.',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.borderDark),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => setState(() => _showRevisionForm = false),
                        child: const Text('Voltar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        text: 'Enviar Revisão',
                        icon: Icons.send_rounded,
                        isLoading: _isRequestingRevision,
                        onPressed: _submitRevision,
                      ),
                    ),
                  ],
                ),
              ],
            ] else ...[
              // Visualização do Freelancer
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryLight.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_top_rounded, color: AppColors.primaryLight, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.milestone.status == MilestoneStatus.inRevision
                            ? 'O cliente solicitou ajustes neste marco. Você pode reescrever a entrega e enviar novos arquivos.'
                            : 'Entrega enviada com sucesso! Aguardando o cliente aprovar para transferir ${CurrencyFormatter.format(widget.milestone.amount)} para sua carteira.',
                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimaryDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
