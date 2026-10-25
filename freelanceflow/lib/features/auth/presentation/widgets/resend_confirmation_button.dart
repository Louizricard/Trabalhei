import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../providers/auth_state_provider.dart';
import '../providers/pending_confirmation_provider.dart';

/// Reenvia o link de confirmação, respeitando o intervalo entre pedidos.
/// [compact] usa um botão de texto (para o aviso do login).
class ResendConfirmationButton extends ConsumerStatefulWidget {
  final String email;
  final bool compact;

  const ResendConfirmationButton({
    super.key,
    required this.email,
    this.compact = false,
  });

  @override
  ConsumerState<ResendConfirmationButton> createState() =>
      _ResendConfirmationButtonState();
}

class _ResendConfirmationButtonState
    extends ConsumerState<ResendConfirmationButton> {
  bool _isResending = false;

  Future<void> _resend() async {
    setState(() => _isResending = true);
    try {
      await ref
          .read(authProvider.notifier)
          .resendSignupConfirmation(widget.email);
      ref.read(resendCooldownProvider.notifier).start();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enviamos um novo link de confirmação.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyError(e)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final secondsLeft = ref.watch(resendCooldownProvider);
    final label = secondsLeft > 0
        ? 'Reenviar em ${secondsLeft}s'
        : 'Reenviar e-mail';
    final onPressed = secondsLeft > 0 || _isResending ? null : _resend;

    if (widget.compact) {
      return TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.warning,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
        ),
        icon: _isResending
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.warning,
                ),
              )
            : const Icon(Icons.refresh_rounded, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      );
    }

    return CustomButton(
      text: label,
      variant: ButtonVariant.outline,
      icon: Icons.refresh_rounded,
      isLoading: _isResending,
      onPressed: onPressed,
    );
  }
}
