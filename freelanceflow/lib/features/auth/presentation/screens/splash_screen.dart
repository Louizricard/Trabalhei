import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/session_policy.dart';
import '../email_link.dart';
import '../providers/auth_state_provider.dart';
import '../providers/pending_confirmation_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );

    _animController.forward();
    _checkAuthAndNavigate();
  }

  void _checkAuthAndNavigate() {
    final link = kIsWeb ? EmailLink.fromUri(Uri.base) : null;
    if (link != null) {
      link.open(ref).then((route) {
        if (mounted) context.go(route);
      });
      return;
    }
    // Garantir exibição da splash por pelo menos 1.8 segundos para visualização da marca
    final returning = SessionPolicy.hasSignedInBefore();
    _timer = Timer(const Duration(milliseconds: 1800), () async {
      if (!mounted) return;
      // valueOrNull: em estado de erro, `.value` lançava e a splash travava.
      if (ref.read(authProvider).valueOrNull != null) {
        context.go('/jobs');
      } else if (_cameFromEmailLink()) {
        ref.read(pendingConfirmationProvider.notifier).clear();
        context.go(
          '/login?notice=${Uri.encodeComponent('E-mail confirmado! Agora é só entrar com seu e-mail e senha.')}',
        );
      } else {
        // Primeira visita: explora o mural sem conta; quem já entrou, faz login.
        final hasSignedIn = await returning;
        if (mounted) context.go(hasSignedIn ? '/login' : '/jobs');
      }
    });
  }

  /// Link de confirmação do e-mail (fluxo PKCE: `?code=...` na URL). Aberto em
  /// outro navegador a sessão não é criada, mas a conta já está confirmada.
  bool _cameFromEmailLink() =>
      kIsWeb && Uri.base.queryParameters.containsKey('code');

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Arte da Splash Screen Oficial
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Image.asset(
                    'assets/images/splash_screen.png',
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
              // Indicador discreto na base para feedback visual de carregamento
              Positioned(
                bottom: 36,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                      backgroundColor: AppColors.primaryContainer,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
