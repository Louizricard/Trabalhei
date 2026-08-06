import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/attachment_widgets.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../domain/entities/dispute.dart';
import '../providers/disputes_provider.dart';

class DisputeDetailScreen extends ConsumerStatefulWidget {
  final String disputeId;

  const DisputeDetailScreen({super.key, required this.disputeId});

  @override
  ConsumerState<DisputeDetailScreen> createState() => _DisputeDetailScreenState();
}

class _DisputeDetailScreenState extends ConsumerState<DisputeDetailScreen> {
  final _messageController = TextEditingController();
  List<PickedFileData> _selectedFiles = [];
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendEvidence(Dispute dispute) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insira uma mensagem ou anexe arquivos de evidência.')),
      );
      return;
    }

    final user = ref.read(authProvider).value;
    if (user == null) return;

    setState(() => _isSending = true);
    final storage = ref.read(storageServiceProvider);

    try {
      List<Map<String, dynamic>> uploaded = [];
      if (_selectedFiles.isNotEmpty) {
        uploaded = await storage.uploadMultipleFiles(
          bucket: 'dispute_attachments',
          folderPath: 'disputes/${dispute.id}',
          files: _selectedFiles,
        );
      }

      await ref.read(disputeRepositoryProvider).addDisputeMessage(
            disputeId: dispute.id,
            message: text,
            attachments: uploaded,
          );

      _messageController.clear();
      setState(() => _selectedFiles = []);
      ref.invalidate(disputeDetailProvider(dispute.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evidência enviada com sucesso para a equipe de mediação.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar evidência: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disputeAsync = ref.watch(disputeDetailProvider(widget.disputeId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mediação & Disputa'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
      ),
      body: ResponsiveLayout(
        maxWidth: 800,
        child: disputeAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: EmptyStateWidget(
              icon: Icons.error_outline_rounded,
              title: 'Erro ao carregar disputa',
              description: err.toString(),
            ),
          ),
          data: (dispute) {
            if (dispute == null) {
              return const Center(
                child: EmptyStateWidget(
                  icon: Icons.search_off_rounded,
                  title: 'Disputa não encontrada',
                  description: 'Não foi possível localizar as informações desta mediação.',
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status & Escrow Lock Banner
                  GlassCard(
                    padding: const EdgeInsets.all(18),
                    backgroundColor: AppColors.error.withAlpha(20),
                    borderColor: AppColors.error.withAlpha(80),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.lock_rounded, color: AppColors.error, size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Fundo de Escrow Congelado',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.error),
                                  ),
                                  Text(
                                    'Status atual: ${dispute.statusLabel}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.error.withAlpha(40),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.error),
                              ),
                              child: Text(
                                dispute.statusLabel,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Enquanto esta disputa estiver em andamento, os pagamentos relacionados a este marco estão protegidos e não podem ser liberados sem a decisão da equipe de suporte Trabalhei.',
                          style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondaryDark),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Resumo da Disputa
                  GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Detalhes da Solicitação', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 12),
                        _buildDetailRow('Motivo:', dispute.reason),
                        const SizedBox(height: 8),
                        _buildDetailRow('Aberta em:', DateFormatter.dateTime(dispute.createdAt)),
                        if (dispute.milestoneId != null) ...[
                          const SizedBox(height: 8),
                          _buildDetailRow('Marco afetado:', dispute.milestoneId!),
                        ],
                        const SizedBox(height: 12),
                        const Text('Descrição:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondaryDark)),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevatedDark,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.borderDark),
                          ),
                          child: Text(
                            dispute.description,
                            style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textPrimaryDark),
                          ),
                        ),
                        if (dispute.evidenceAttachments.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          AttachmentCardsList(
                            attachments: dispute.evidenceAttachments,
                            title: 'Evidências Iniciais Anexadas (${dispute.evidenceAttachments.length})',
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Envio de Novas Evidências
                  GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Adicionar Evidências / Esclarecimento',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Envie prints de conversas, links de repositórios ou documentos para ajudar na resolução.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                        ),
                        const SizedBox(height: 14),
                        CustomTextField(
                          controller: _messageController,
                          label: 'Mensagem para a equipe de mediação',
                          hint: 'Descreva novos fatos ou forneça detalhes...',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        AttachmentPickerSection(
                          selectedFiles: _selectedFiles,
                          onChanged: (files) => setState(() => _selectedFiles = files),
                          title: 'Anexar Arquivos / Prints',
                        ),
                        const SizedBox(height: 16),
                        CustomButton(
                          text: 'Enviar Evidências',
                          icon: Icons.send_rounded,
                          isLoading: _isSending,
                          width: double.infinity,
                          onPressed: () => _sendEvidence(dispute),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryDark)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark)),
        ),
      ],
    );
  }
}
