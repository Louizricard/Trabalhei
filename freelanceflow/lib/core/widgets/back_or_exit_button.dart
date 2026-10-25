import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Botão "voltar" para telas que podem ser abertas direto por um link (ex.:
/// Termos, a partir da homepage). Sem tela anterior no app, volta para a
/// homepage na Web e para [fallbackRoute] no Android e no Windows.
class BackOrExitButton extends StatelessWidget {
  final String fallbackRoute;

  const BackOrExitButton({super.key, required this.fallbackRoute});

  Future<void> _leave(BuildContext context) async {
    if (context.canPop()) return context.pop();
    if (kIsWeb) {
      // A homepage fica na raiz do mesmo domínio; o app, em /app/.
      await launchUrl(Uri.base.resolve('/'), webOnlyWindowName: '_self');
      return;
    }
    context.go(fallbackRoute);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      tooltip: 'Voltar',
      onPressed: () => _leave(context),
    );
  }
}
