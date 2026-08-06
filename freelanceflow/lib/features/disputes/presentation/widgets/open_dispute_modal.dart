import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/attachment_widgets.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../chat/domain/entities/conversation.dart';
import '../providers/disputes_provider.dart';

class OpenDisputeModal extends ConsumerStatefulWidget {
  final Conversation conversation;

  const OpenDisputeModal({super.key, required this.conversation});

  @override
  ConsumerState<OpenDisputeModal> createState() => _OpenDisputeModalState();
}

class _OpenDisputeModalState extends ConsumerState<OpenDisputeModal> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  String? _selectedMilestoneId;
  String _selectedReason = 'Não entrega do trabalho acordado';
  List<PickedFileData> _selectedFiles = [];
  bool _isLoading = false;

  final _reasons = [
    'Não entrega do trabalho acordado',
    'Qualidade incompatível com o briefing',
    'Abandono de comunicação / sumiço',
    'Divergência de escopo ou valores adicionais',
    'Atraso excessivo e injustificado',
    'Outro motivo',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.conversation.milestones.isNotEmpty) {
      _selectedMilestoneId = widget.conversation.milestones.first.id;
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submitDispute() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (widget.conversation.contractId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este chat não possui um contrato ativo associado.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final storage = ref.read(storageServiceProvider);
      final uploadedAttachments = <Map<String, dynamic>>[];

      for (final file in _selectedFiles) {
        final result = await storage.uploadFile(
          bucket: 'dispute_attachments',
          folder: widget.conversation.contractId!,
          file: file,
        );
        if (result != null) {
          uploadedAttachments.add(result.toJson());
        }
      }

      await ref.read(disputeRepositoryProvider).openDispute(
            contractId: widget.conversation.contractId!,
            milestoneId: _selectedMilestoneId,
            reason: _selectedReason,
            description: _descController.text.trim(),
            evidenceAttachments: uploadedAttachments,
            conversationId: widget.conversation.id,
          );

      if (mounted) {
        Navigator.of(context).pop();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surfaceDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.shield_rounded, color: AppColors.warning),
                SizedBox(width: 8),
                Text('Mediação Acionada'),
              ],
            ),
            content: const Text(
              'A disputa foi aberta e os fundos em Escrow do marco foram congelados preventivamente.\n\n'
              'Nossa equipe de suporte do Trabalhei analisará os anexos, histórico de mensagens e entregas para intermediar o caso.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir disputa: $e'), backgroundColor: AppColors.error),
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
                  const Row(
                    children: [
                      Icon(Icons.gavel_rounded, color: AppColors.error),
                      SizedBox(width: 8),
                      Text(
                        'Abrir Mediação / Disputa',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GlassCard(
                padding: const EdgeInsets.all(12),
                backgroundColor: AppColors.warning.withAlpha(20),
                borderColor: AppColors.warning.withAlpha(60),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_clock_rounded, color: AppColors.warning, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ao abrir uma disputa, o valor do marco em Escrow é congelado e a equipe do Trabalhei atuará como mediadora imparcial.',
                        style: TextStyle(fontSize: 12, color: AppColors.textPrimaryDark, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (widget.conversation.milestones.isNotEmpty) ...[
                const Text('Marco em Questão:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimaryDark)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedMilestoneId,
                  dropdownColor: AppColors.surfaceElevatedDark,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: widget.conversation.milestones.map((m) {
                    return DropdownMenuItem(
                      value: m.id,
                      child: Text(m.title, style: const TextStyle(fontSize: 13, color: AppColors.textPrimaryDark)),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedMilestoneId = val),
                ),
                const SizedBox(height: 14),
              ],
              const Text('Motivo Principal:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimaryDark)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedReason,
                dropdownColor: AppColors.surfaceElevatedDark,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _reasons.map((r) {
                  return DropdownMenuItem(
                    value: r,
                    child: Text(r, style: const TextStyle(fontSize: 13, color: AppColors.textPrimaryDark)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedReason = val);
                },
              ),
              const SizedBox(height: 14),
              CustomTextField(
                controller: _descController,
                label: 'Descrição Detalhada do Ocorrido',
                hint: 'Explique o motivo da disputa, o que foi combinado e onde houve divergência...',
                maxLines: 4,
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Descreva o ocorrido detalhadamente' : null,
              ),
              const SizedBox(height: 14),
              AttachmentPickerSection(
                selectedFiles: _selectedFiles,
                onChanged: (files) => setState(() => _selectedFiles = files),
                title: 'Provas & Evidências (Prints, PDFs, Documentos)',
                hintText: 'Anexe comprovantes ou prints para embasar sua solicitação.',
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Confirmar e Enviar para Mediação',
                icon: Icons.shield_rounded,
                isLoading: _isLoading,
                width: double.infinity,
                variant: ButtonVariant.danger,
                onPressed: _submitDispute,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
