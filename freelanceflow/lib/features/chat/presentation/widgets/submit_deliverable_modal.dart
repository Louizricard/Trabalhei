import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/attachment_widgets.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../domain/entities/conversation.dart';
import '../providers/chat_provider.dart';

class SubmitDeliverableModal extends ConsumerStatefulWidget {
  final Conversation conversation;
  final ContractMilestone milestone;

  const SubmitDeliverableModal({
    super.key,
    required this.conversation,
    required this.milestone,
  });

  @override
  ConsumerState<SubmitDeliverableModal> createState() =>
      _SubmitDeliverableModalState();
}

class _SubmitDeliverableModalState
    extends ConsumerState<SubmitDeliverableModal> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  List<PickedFileData> _selectedFiles = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = ref.read(authProvider).value;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final storage = ref.read(storageServiceProvider);
      final uploadedAttachments = <Map<String, dynamic>>[];

      for (final file in _selectedFiles) {
        final result = await storage.uploadFile(
          bucket: 'chat_attachments',
          folder: 'deliverables/${widget.milestone.id}',
          file: file,
        );
        if (result != null) {
          uploadedAttachments.add(result.toJson());
        }
      }

      await ref
          .read(chatRepositoryProvider)
          .submitMilestoneDeliverable(
            conversationId: widget.conversation.id,
            milestoneId: widget.milestone.id,
            notes: _notesController.text.trim(),
            attachments: uploadedAttachments,
          );

      ref.invalidate(conversationDetailProvider(widget.conversation.id));
      ref.invalidate(conversationsListProvider);
      ref.invalidate(freelancerStatsProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🎉 Entrega do marco enviada ao cliente com sucesso!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao enviar entrega: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
      child: Form(
        key: _formKey,
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
                      'Entregar: ${widget.milestone.title}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Envie os detalhes do trabalho concluído e anexe os arquivos finais para a aprovação do cliente.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _notesController,
                label: 'Descrição da Entrega & Instruções',
                hint:
                    'Ex: Concluí a tela conforme solicitado. Links, documentação ou orientações para teste...',
                maxLines: 4,
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Informe uma descrição para a entrega'
                    : null,
              ),
              const SizedBox(height: 16),
              AttachmentPickerSection(
                selectedFiles: _selectedFiles,
                onChanged: (files) => setState(() => _selectedFiles = files),
                title: 'Arquivos Entregues (Projetos, ZIPs, PDFs, Telas)',
                hintText:
                    'Anexe o código empacotado, prints ou documentos comprobatórios.',
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Enviar Entrega para Aprovação',
                icon: Icons.send_rounded,
                isLoading: _isLoading,
                width: double.infinity,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
