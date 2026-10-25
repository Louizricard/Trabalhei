import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/pending_confirmation_provider.dart';
import 'resend_confirmation_button.dart';

/// Aviso fixo de "confirme seu e-mail" para um cadastro pendente. Não tem
/// botão de fechar: some quando a conta entra (e-mail confirmado) ou quando o
/// usuário escolhe usar outro e-mail.
class PendingConfirmationBanner extends ConsumerWidget {
  const PendingConfirmationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(pendingConfirmationProvider);
    if (email == null || email.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withAlpha(110)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(
            '/confirm-email?email=${Uri.encodeComponent(email)}',
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.mark_email_unread_outlined,
                        color: AppColors.warning,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Confirme seu e-mail',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text.rich(
                            TextSpan(
                              text: 'Enviamos um link para ',
                              children: [
                                TextSpan(
                                  text: email,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimaryDark,
                                  ),
                                ),
                                const TextSpan(
                                  text:
                                      '. Toque nele para liberar sua conta e '
                                      'depois entre aqui.',
                                ),
                              ],
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  alignment: WrapAlignment.end,
                  children: [
                    ResendConfirmationButton(email: email, compact: true),
                    TextButton(
                      onPressed: () => ref
                          .read(pendingConfirmationProvider.notifier)
                          .clear(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondaryDark,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text(
                        'Usar outro e-mail',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
