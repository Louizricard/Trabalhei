import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/guest_access.dart';
import '../../domain/admin_models.dart';
import '../providers/admin_provider.dart';

/// Abre o formulário de denúncia de uma vaga ou perfil. Visitantes recebem o
/// aviso para criar conta antes.
Future<void> showReportDialog(
  BuildContext context,
  WidgetRef ref, {
  required ReportTarget target,
  required String targetId,
}) async {
  final what = target == ReportTarget.job ? 'esta vaga' : 'este perfil';
  if (!await requireAccount(context, ref, action: 'denunciar $what')) return;
  if (!context.mounted) return;
  final sent = await showDialog<bool>(
    context: context,
    builder: (_) => _ReportDialog(target: target, targetId: targetId),
  );
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Denúncia enviada. A moderação vai analisar. Obrigado por ajudar a manter o Trabalhei seguro.',
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }
}

class _ReportDialog extends ConsumerStatefulWidget {
  final ReportTarget target;
  final String targetId;

  const _ReportDialog({required this.target, required this.targetId});

  @override
  ConsumerState<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<_ReportDialog> {
  ReportReason? _reason;
  final _details = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reason == null) {
      setState(() => _error = 'Escolha um motivo.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(adminRepositoryProvider)
          .report(
            target: widget.target,
            targetId: widget.targetId,
            reason: _reason!,
            details: _details.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.target == ReportTarget.job
        ? 'Denunciar vaga'
        : 'Denunciar perfil';
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A denúncia é anônima para a outra pessoa. Qual é o problema?',
                style: TextStyle(color: AppColors.textSecondaryDark),
              ),
              const SizedBox(height: 8),
              RadioGroup<ReportReason>(
                groupValue: _reason,
                onChanged: (v) => setState(() => _reason = v),
                child: Column(
                  children: [
                    for (final r in ReportReason.values)
                      RadioListTile<ReportReason>(
                        value: r,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(r.label),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _details,
                maxLines: 3,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Detalhes (opcional)',
                  hintText: 'Conte o que aconteceu',
                ),
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: Text(_sending ? 'Enviando...' : 'Enviar denúncia'),
        ),
      ],
    );
  }
}
