import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import 'providers/auth_state_provider.dart';

/// Telas que um visitante sem conta pode abrir: o mural, os detalhes de uma
/// vaga, perfis públicos e a busca de freelancers. O resto pede login.
bool isPublicRoute(String location) {
  final segments = Uri.parse(location).pathSegments;
  if (segments.isEmpty) return false;
  return switch (segments.first) {
    'jobs' =>
      segments.length == 1 || (segments.length == 2 && segments[1] != 'create'),
    'profile' => segments.length == 2,
    'freelancers' => segments.length == 1,
    _ => false,
  };
}

/// Destino depois do login: só caminhos internos do app (nunca outro site).
String safeReturnPath(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return '/jobs';
  }
  final path = Uri.parse(from).path;
  const authRoutes = ['/login', '/register', '/splash', '/confirm-email'];
  return authRoutes.contains(path) ? '/jobs' : from;
}

/// Rota de login ou cadastro que, ao concluir, volta para [from].
String authRouteReturningTo(String route, String from) =>
    '$route?from=${Uri.encodeComponent(from)}';

/// Libera a ação para quem tem conta. Para visitantes, explica por que ela
/// pede uma conta e oferece cadastro ou login. Depois de entrar, segue para
/// [returnTo] (a ação pedida) ou volta para a mesma tela. Retorna `true` só
/// quando o usuário já está logado.
Future<bool> requireAccount(
  BuildContext context,
  WidgetRef ref, {
  required String action,
  String? returnTo,
}) async {
  if (ref.read(authProvider).valueOrNull != null) return true;
  final from = returnTo ?? GoRouter.of(context).state.uri.toString();
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: AppColors.surfaceDark,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _SignInPromptSheet(
      action: action,
      onChoose: (route) {
        Navigator.of(sheetContext).pop();
        // `go` muda o endereço: o voltar do navegador retorna para cá.
        context.go(authRouteReturningTo(route, from));
      },
    ),
  );
  return false;
}

class _SignInPromptSheet extends StatelessWidget {
  final String action;
  final ValueChanged<String> onChoose;

  const _SignInPromptSheet({required this.action, required this.onChoose});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_open_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Crie sua conta para $action',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'É grátis e leva um minuto. Depois de entrar, você volta para esta tela.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                const SizedBox(height: 24),
                CustomButton(
                  text: 'Criar conta grátis',
                  width: double.infinity,
                  onPressed: () => onChoose('/register'),
                ),
                const SizedBox(height: 12),
                CustomButton(
                  text: 'Já tenho conta',
                  variant: ButtonVariant.outline,
                  width: double.infinity,
                  onPressed: () => onChoose('/login'),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Continuar explorando',
                    style: TextStyle(color: AppColors.textSecondaryDark),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso no topo do mural para quem ainda não tem conta.
class GuestWelcomeBanner extends StatelessWidget {
  const GuestWelcomeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final from = GoRouter.of(context).state.uri.toString();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withAlpha(80)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Você está explorando sem conta. ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text:
                        'Para enviar propostas, publicar vagas ou conversar, crie sua conta grátis.',
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textPrimaryDark,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () =>
                    context.go(authRouteReturningTo('/login', from)),
                child: const Text('Entrar'),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: () =>
                    context.go(authRouteReturningTo('/register', from)),
                child: const Text('Criar conta'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
