import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../providers/resume_provider.dart';

/// Currículo em PDF do freelancer: enviar, abrir, trocar ou remover. Cada ação
/// vale na hora, sem depender do "Salvar alterações".
class ResumeField extends ConsumerStatefulWidget {
  const ResumeField({super.key});

  @override
  ConsumerState<ResumeField> createState() => _ResumeFieldState();
}

class _ResumeFieldState extends ConsumerState<ResumeField> {
  bool _busy = false;

  /// Executa a ação; `false` como resultado significa que o usuário cancelou.
  Future<void> _run(Future<Object?> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      final result = await action();
      if (mounted && result != false) _snack(done, AppColors.success);
    } catch (e) {
      if (mounted) _snack(friendlyError(e), AppColors.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text, Color color) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(text), backgroundColor: color));

  Future<void> _upload() =>
      _run(() => ref.read(uploadResumeProvider)(), 'Currículo enviado.');

  @override
  Widget build(BuildContext context) {
    final url = ref.watch(authProvider).valueOrNull?.resumeUrl;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.picture_as_pdf_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  url == null
                      ? 'Currículo (PDF, até 5 MB)'
                      : 'Currículo enviado',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryDark,
                  ),
                ),
              ),
              if (_busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Aparece no seu perfil para quem está logado no Trabalhei.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: [
              if (url != null)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => ref
                            .read(storageServiceProvider)
                            .launchAttachment(url),
                  child: const Text('Abrir'),
                ),
              TextButton(
                onPressed: _busy ? null : _upload,
                child: Text(url == null ? 'Enviar PDF' : 'Trocar'),
              ),
              if (url != null)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => ref
                              .read(removeResumeProvider)()
                              .then((_) => true),
                          'Currículo removido.',
                        ),
                  child: const Text('Remover'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
