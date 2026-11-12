import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trabalhei/core/errors/backend_errors.dart';
import 'package:trabalhei/core/theme/app_colors.dart';
import 'package:trabalhei/features/chat/domain/entities/conversation.dart';
import 'package:trabalhei/features/chat/presentation/providers/chat_provider.dart';
import 'package:trabalhei/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:trabalhei/features/jobs/presentation/providers/jobs_provider.dart';

/// Encerramento de contrato ativo por qualquer uma das partes. O motivo
/// (10 a 500 caracteres) vai para o chat e para a notificação da outra parte.
/// Devolve true quando o contrato foi encerrado.
class CancelContractDialog extends ConsumerStatefulWidget {
  final Conversation conversation;

  const CancelContractDialog({super.key, required this.conversation});

  static Future<bool> show(
    BuildContext context,
    Conversation conversation,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => CancelContractDialog(conversation: conversation),
    );
    return result ?? false;
  }

  @override
  ConsumerState<CancelContractDialog> createState() =>
      _CancelContractDialogState();
}

class _CancelContractDialogState extends ConsumerState<CancelContractDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  static String? validateReason(String? value) {
    final length = (value ?? '').trim().length;
    if (length < 10) return 'Explique o motivo (mínimo de 10 caracteres).';
    if (length > 500) return 'Use no máximo 500 caracteres.';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref
          .read(chatRepositoryProvider)
          .cancelContract(
            contractId: widget.conversation.contractId!,
            reason: _reason.text.trim(),
          );
      ref.invalidate(conversationDetailProvider(widget.conversation.id));
      ref.invalidate(conversationsListProvider);
      ref.invalidate(clientStatsProvider);
      ref.invalidate(freelancerStatsProvider);
      ref.invalidate(jobDetailProvider);
      ref.invalidate(clientJobsProvider);
      ref.invalidate(jobsListProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceDark,
      title: const Text(
        'Encerrar contrato',
        style: TextStyle(color: AppColors.textPrimaryDark),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'O contrato e a vaga serão encerrados e a outra parte será '
              'avisada. Essa ação não pode ser desfeita.',
              style: TextStyle(color: AppColors.textSecondaryDark),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('cancel-contract-reason'),
              controller: _reason,
              maxLines: 3,
              maxLength: 500,
              enabled: !_isLoading,
              validator: validateReason,
              style: const TextStyle(color: AppColors.textPrimaryDark),
              decoration: const InputDecoration(labelText: 'Motivo'),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Voltar'),
        ),
        ElevatedButton(
          key: const Key('confirm-cancel-contract'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.pureWhite,
          ),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Encerrar'),
        ),
      ],
    );
  }
}
