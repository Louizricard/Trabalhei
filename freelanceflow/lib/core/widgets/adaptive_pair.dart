import 'package:flutter/material.dart';

/// Dois controles lado a lado que viram um por linha quando não cabem.
///
/// O limite cresce com o tamanho de fonte escolhido no aparelho: com letra
/// grande, rótulos que quebrariam em duas linhas desalinhariam os campos (ou
/// cortariam o texto dos botões), então a dupla empilha antes disso.
class AdaptivePair extends StatelessWidget {
  final Widget first;
  final Widget second;

  /// Largura mínima, com fonte no tamanho padrão, para manter lado a lado.
  final double minRowWidth;
  final double spacing;

  /// Alinhamento vertical na linha: campos alinham pelo topo (as mensagens
  /// abaixo deles podem ter alturas diferentes); botões, pelo centro.
  final CrossAxisAlignment rowAlignment;

  const AdaptivePair({
    super.key,
    required this.first,
    required this.second,
    this.minRowWidth = 440,
    this.spacing = 12,
    this.rowAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < minRowWidth * scale) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first,
              SizedBox(height: spacing),
              second,
            ],
          );
        }
        return Row(
          crossAxisAlignment: rowAlignment,
          children: [
            Expanded(child: first),
            SizedBox(width: spacing),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}
