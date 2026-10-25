import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import 'profile_settings.dart';

/// Exclusão de conta pelo próprio usuário (LGPD). Pede que o usuário digite
/// a palavra de confirmação antes de chamar o servidor.
class DeleteAccountButton extends ConsumerStatefulWidget {
  const DeleteAccountButton({super.key});

  @override
  ConsumerState<DeleteAccountButton> createState() =>
      _DeleteAccountButtonState();
}

class _DeleteAccountButtonState extends ConsumerState<DeleteAccountButton> {
  static const _confirmationWord = 'EXCLUIR';
  bool _isDeleting = false;

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConfirmDeleteDialog(word: _confirmationWord),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      // Ao concluir, o authProvider fica nulo e o router leva ao login.
      await ref.read(authProvider.notifier).deleteAccount();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyError(e)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProfileSettingsTile(
      icon: Icons.delete_forever_outlined,
      title: 'Excluir minha conta',
      subtitle: 'Apaga seu perfil e seus dados de forma permanente',
      isDestructive: true,
      isLoading: _isDeleting,
      onTap: _handleDelete,
    );
  }
}

class _ConfirmDeleteDialog extends StatefulWidget {
  final String word;

  const _ConfirmDeleteDialog({required this.word});

  @override
  State<_ConfirmDeleteDialog> createState() => _ConfirmDeleteDialogState();
}

class _ConfirmDeleteDialogState extends State<_ConfirmDeleteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Excluir conta?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seu perfil, portfólio, vagas abertas, propostas pendentes, '
              'notificações e arquivos serão apagados e a assinatura Pro, se '
              'houver, será cancelada. Contratos já concluídos ficam no '
              'histórico da outra parte com o seu nome anonimizado.\n\n'
              'Esta ação não pode ser desfeita.',
            ),
            const SizedBox(height: 16),
            Text('Digite ${widget.word} para confirmar:'),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Voltar'),
        ),
        TextButton(
          onPressed: _controller.text.trim().toUpperCase() == widget.word
              ? () => Navigator.of(context).pop(true)
              : null,
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Excluir conta'),
        ),
      ],
    );
  }
}
