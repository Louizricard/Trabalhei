import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// "Voltar" de telas internas do app. Volta para a tela anterior quando
/// existe; aberta direto por link (Web) ou notificação, vai para
/// [fallbackRoute] em vez de quebrar a navegação.
class AppBackButton extends StatelessWidget {
  final String fallbackRoute;

  const AppBackButton({super.key, required this.fallbackRoute});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      tooltip: 'Voltar',
      onPressed: () =>
          context.canPop() ? context.pop() : context.go(fallbackRoute),
    );
  }
}
