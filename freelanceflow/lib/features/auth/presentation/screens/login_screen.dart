import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/validators.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../providers/auth_state_provider.dart';
import '../../data/session_policy.dart';
import '../providers/pending_confirmation_provider.dart';
import '../widgets/auth_brand_header.dart';
import '../widgets/keep_signed_in_row.dart';
import '../widgets/pending_confirmation_banner.dart';

class LoginScreen extends ConsumerStatefulWidget {
  /// Mensagem opcional exibida ao abrir a tela (ex.: confirmar e-mail).
  final String? notice;

  const LoginScreen({super.key, this.notice});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _keepSignedIn = true;

  @override
  void initState() {
    super.initState();
    _showNotice(widget.notice);
    SessionPolicy.keepSignedIn().then((keep) {
      if (mounted) setState(() => _keepSignedIn = keep);
    });
    // Cadastro pendente: já deixa o e-mail preenchido (o valor salvo pode
    // chegar depois da abertura da tela).
    ref.listenManual(pendingConfirmationProvider, (previous, email) {
      if (email != null && _emailController.text.isEmpty) {
        _emailController.text = email;
      } else if (email == null && _emailController.text == previous) {
        // "Usar outro e-mail": tira o e-mail que tínhamos preenchido.
        _emailController.clear();
      }
    }, fireImmediately: true);
  }

  // O go_router reaproveita a tela de login quando só o aviso da URL muda
  // (ex.: voltando de outra tela de autenticação); initState não roda de novo.
  @override
  void didUpdateWidget(covariant LoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.notice != oldWidget.notice) _showNotice(widget.notice);
  }

  void _showNotice(String? notice) {
    if (notice == null || notice.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(notice), duration: const Duration(seconds: 8)),
      );
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(authProvider.notifier)
          .signIn(_emailController.text.trim(), _passwordController.text);
      await SessionPolicy.remember(keepSignedIn: _keepSignedIn);
      // Oferece salvar e-mail e senha no gerenciador de senhas do navegador.
      TextInput.finishAutofillContext();
      if (mounted) {
        context.go('/jobs');
      }
    } on EmailNotConfirmedException catch (e) {
      ref.read(pendingConfirmationProvider.notifier).set(e.email);
      if (mounted) {
        setState(() => _isLoading = false);
        context.push('/confirm-email?email=${Uri.encodeComponent(e.email)}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ResponsiveLayout(
              maxWidth: 440,
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AuthBrandHeader(),
                      const SizedBox(height: 32),
                      const PendingConfirmationBanner(),

                      GlassCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            CustomTextField(
                              controller: _emailController,
                              label: 'E-mail',
                              hint: 'seu@email.com',
                              prefixIcon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: Validators.email,
                              autofillHints: const [
                                AutofillHints.email,
                                AutofillHints.username,
                              ],
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: _passwordController,
                              label: 'Senha',
                              hint: '••••••••',
                              prefixIcon: Icons.lock_outline_rounded,
                              obscureText: true,
                              validator: (v) => v != null && v.length >= 6
                                  ? null
                                  : 'Mínimo 6 caracteres',
                              autofillHints: const [AutofillHints.password],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _handleLogin(),
                            ),
                            const SizedBox(height: 12),
                            KeepSignedInRow(
                              value: _keepSignedIn,
                              onChanged: (v) =>
                                  setState(() => _keepSignedIn = v),
                            ),
                            const SizedBox(height: 16),
                            CustomButton(
                              text: 'Entrar na Plataforma',
                              isLoading: _isLoading,
                              onPressed: _handleLogin,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Ainda não tem uma conta? ',
                            style: TextStyle(
                              color: AppColors.textSecondaryDark,
                              fontSize: 14,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.push('/register'),
                            child: const Text(
                              'Cadastre-se',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
