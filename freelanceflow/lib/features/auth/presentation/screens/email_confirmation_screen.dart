import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../providers/pending_confirmation_provider.dart';
import '../widgets/resend_confirmation_button.dart';

/// Mostrada logo após o cadastro, enquanto a conta aguarda a confirmação do
/// e-mail. Sem ela o usuário voltava ao login sem entender o que fazer.
class EmailConfirmationScreen extends ConsumerWidget {
  final String email;

  const EmailConfirmationScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sem o parâmetro na URL (ex.: recarregou a página), usa o cadastro salvo.
    final email = this.email.isNotEmpty
        ? this.email
        : ref.watch(pendingConfirmationProvider) ?? '';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ResponsiveLayout(
              maxWidth: 460,
              child: GlassCard(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mark_email_unread_outlined,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Confirme seu e-mail',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text.rich(
                      TextSpan(
                        text:
                            'Sua conta foi criada. Enviamos um link de '
                            'confirmação para ',
                        children: [
                          TextSpan(
                            text: email,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryDark,
                            ),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _Step(
                      number: '1',
                      text:
                          'Abra o e-mail "Confirme seu cadastro no Trabalhei".',
                    ),
                    const _Step(
                      number: '2',
                      text: 'Toque em "Confirmar e-mail".',
                    ),
                    const _Step(
                      number: '3',
                      text: 'Volte aqui e entre com seu e-mail e senha.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Não chegou em alguns minutos? Veja a caixa de spam ou '
                      'peça um novo link.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMutedDark,
                      ),
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      text: 'Ir para o login',
                      icon: Icons.login_rounded,
                      onPressed: () => context.go('/login'),
                    ),
                    const SizedBox(height: 10),
                    if (email.isNotEmpty)
                      ResendConfirmationButton(email: email),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String text;

  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primary,
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
