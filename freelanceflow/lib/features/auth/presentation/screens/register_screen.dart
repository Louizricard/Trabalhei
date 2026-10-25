import '../../../../core/errors/backend_errors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/password_policy.dart';
import '../providers/auth_state_provider.dart';
import '../providers/pending_confirmation_provider.dart';
import '../widgets/pending_confirmation_banner.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  UserRole _selectedRole = UserRole.freelancer;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(authProvider.notifier)
          .signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _nameController.text.trim(),
            role: _selectedRole,
          );
      if (mounted) {
        context.go('/jobs');
      }
    } on EmailConfirmationPendingException catch (e) {
      ref.read(pendingConfirmationProvider.notifier).set(e.email);
      if (mounted) {
        setState(() => _isLoading = false);
        context.go('/confirm-email?email=${Uri.encodeComponent(e.email)}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ResponsiveLayout(
              maxWidth: 460,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PendingConfirmationBanner(),
                    const Text(
                      'Criar Nova Conta',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Escolha seu perfil e comece agora mesmo.',
                      style: TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Role selector tabs
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _RoleTab(
                              title: 'Freelancer',
                              subtitle: 'Quero trabalhar',
                              isSelected: _selectedRole == UserRole.freelancer,
                              icon: Icons.code_rounded,
                              onTap: () => setState(
                                () => _selectedRole = UserRole.freelancer,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _RoleTab(
                              title: 'Cliente',
                              subtitle: 'Quero contratar',
                              isSelected: _selectedRole == UserRole.client,
                              icon: Icons.business_center_rounded,
                              onTap: () => setState(
                                () => _selectedRole = UserRole.client,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CustomTextField(
                            controller: _nameController,
                            label: 'Nome Completo',
                            hint: 'Ex: Carlos Oliveira',
                            prefixIcon: Icons.person_outline_rounded,
                            validator: (v) => v != null && v.length >= 3
                                ? null
                                : 'Insira seu nome completo',
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _emailController,
                            label: 'E-mail',
                            hint: 'seu@email.com',
                            prefixIcon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => v != null && v.contains('@')
                                ? null
                                : 'E-mail inválido',
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _passwordController,
                            label: 'Senha',
                            hint: 'Mínimo $minPasswordLength caracteres',
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: true,
                            validator: (v) =>
                                v != null && v.length >= minPasswordLength
                                ? null
                                : 'Mínimo $minPasswordLength caracteres',
                          ),
                          const SizedBox(height: 16),
                          const _TermsAcceptanceField(),
                          const SizedBox(height: 16),
                          CustomButton(
                            text: 'Finalizar Cadastro',
                            isLoading: _isLoading,
                            onPressed: _handleRegister,
                          ),
                        ],
                      ),
                    ),
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

class _RoleTab extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;

  const _RoleTab({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? AppColors.onPrimary
                  : AppColors.textSecondaryDark,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? AppColors.onPrimary
                    : AppColors.textPrimaryDark,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected
                    ? AppColors.onPrimary.withAlpha(200)
                    : AppColors.textMutedDark,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aceite obrigatório dos Termos de Uso e da Política de Privacidade. Valida
/// junto com o restante do formulário.
class _TermsAcceptanceField extends StatelessWidget {
  const _TermsAcceptanceField();

  @override
  Widget build(BuildContext context) {
    return FormField<bool>(
      initialValue: false,
      validator: (accepted) => accepted == true
          ? null
          : 'Aceite os Termos de Uso e a Política de Privacidade',
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: field.value ?? false,
                activeColor: AppColors.primary,
                onChanged: field.didChange,
              ),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Li e aceito os ',
                      style: TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 13,
                      ),
                    ),
                    InkWell(
                      onTap: () => context.push('/terms'),
                      child: const Text(
                        'Termos de Uso e a Política de Privacidade',
                        style: TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (field.hasError)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                field.errorText!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
