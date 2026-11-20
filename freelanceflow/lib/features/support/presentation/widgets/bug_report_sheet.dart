import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/bug_report.dart';
import '../providers/bug_report_controller.dart';

/// Abre o formulário "Reportar um bug".
Future<void> showBugReportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.transparent,
    isScrollControlled: true,
    builder: (_) => const BugReportSheet(),
  );
}

/// Descrição obrigatória, captura de tela opcional e envio único.
class BugReportSheet extends ConsumerStatefulWidget {
  const BugReportSheet({super.key});

  @override
  ConsumerState<BugReportSheet> createState() => _BugReportSheetState();
}

class _BugReportSheetState extends ConsumerState<BugReportSheet> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  BugScreenshot? _screenshot;
  String? _screenshotError;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    setState(() => _screenshotError = null);
    try {
      final picked = await ref
          .read(storageServiceProvider)
          .pickImage(maxBytes: BugReportRules.maxScreenshotBytes);
      if (picked == null) return;
      final error = BugReportRules.validateScreenshot(
        picked.mimeType,
        picked.size,
      );
      setState(() {
        _screenshotError = error;
        _screenshot = error == null
            ? BugScreenshot(bytes: picked.bytes, mimeType: picked.mimeType)
            : null;
      });
    } catch (e) {
      setState(() => _screenshotError = friendlyError(e));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final sent = await ref
          .read(bugReportControllerProvider.notifier)
          .submit(description: _description.text, screenshot: _screenshot);
      if (!sent) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Relatório enviado. Obrigado por ajudar a melhorar!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Não foi possível enviar: ${friendlyError(e)}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sending = ref.watch(bugReportControllerProvider).isLoading;
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.borderDark,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Reportar um bug',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Conte o que aconteceu e o que você esperava. A plataforma, a versão do app e a data vão junto.',
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _description,
                  enabled: !sending,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: BugReportRules.maxDescription,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Descrição do problema',
                    hintText:
                        'Ex.: ao tocar em Enviar proposta, a tela fica carregando.',
                    alignLabelWithHint: true,
                  ),
                  validator: BugReportRules.validateDescription,
                ),
                const SizedBox(height: 8),
                _ScreenshotField(
                  screenshot: _screenshot,
                  error: _screenshotError,
                  enabled: !sending,
                  onPick: _pickScreenshot,
                  onRemove: () => setState(() => _screenshot = null),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: sending ? null : _submit,
                  child: sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enviar relatório'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScreenshotField extends StatelessWidget {
  final BugScreenshot? screenshot;
  final String? error;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _ScreenshotField({
    required this.screenshot,
    required this.error,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final shot = screenshot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (shot == null)
          OutlinedButton.icon(
            onPressed: enabled ? onPick : null,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: const Text('Anexar captura de tela (opcional)'),
          )
        else
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  shot.bytes,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  semanticLabel: 'Prévia da captura de tela',
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Captura anexada',
                  style: TextStyle(color: AppColors.textSecondaryDark),
                ),
              ),
              IconButton(
                tooltip: 'Remover captura',
                onPressed: enabled ? onRemove : null,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        const SizedBox(height: 6),
        Text(
          error ??
              '${BugReportRules.screenshotTypesLabel}, até 5 MB. Evite mostrar senhas ou dados de pagamento.',
          style: TextStyle(
            fontSize: 12,
            color: error == null ? AppColors.textMutedDark : AppColors.error,
          ),
        ),
      ],
    );
  }
}
