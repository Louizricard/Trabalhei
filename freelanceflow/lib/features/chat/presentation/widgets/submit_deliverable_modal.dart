import 'package:trabalhei/core/errors/backend_errors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/attachment_store.dart';
import '../../../../core/widgets/attachment_widgets.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/field_label.dart';
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
      await AttachmentSaveFlow(ref.read(storageServiceProvider)).run(
        bucket: 'chat_attachments',
        folder: 'deliverables/${widget.milestone.id}',
        newFiles: _selectedFiles,
        save: (uploaded) => ref
            .read(chatRepositoryProvider)
            .submitMilestoneDeliverable(
              milestoneId: widget.milestone.id,
              notes: _notesController.text.trim(),
              attachments: [for (final a in uploaded) a.toJson()],
            ),
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
            content: Text('Falha ao enviar entrega: ${friendlyError(e)}'),
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
                label: 'O que foi entregue',
                requirement: FieldRequirement.required,
                hint:
                    'Ex.: Logotipo final em PDF e PNG, com o manual de uso '
                    'das cores.',
                helperText:
                    'Explique o que está nos arquivos e como o cliente '
                    'pode conferir.',
                maxLines: 4,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                validator: Validators.minLength('o que foi entregue', 10),
              ),
              const SizedBox(height: 16),
              AttachmentPickerSection(
                selectedFiles: _selectedFiles,
                onChanged: (files) => setState(() => _selectedFiles = files),
                title: 'Arquivos da entrega (opcional)',
                hintText: 'Arquivos finais, prints ou um ZIP com tudo.',
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
