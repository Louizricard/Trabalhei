import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Como o rótulo indica a obrigatoriedade do campo.
enum FieldRequirement {
  /// Sem marcação (formulários curtos em que tudo é óbvio).
  none,

  /// Mostra um asterisco; o leitor de tela anuncia "obrigatório".
  required,

  /// Mostra "(opcional)" ao lado do rótulo.
  optional,
}

/// Rótulo padrão dos campos de formulário, acima do controle.
class FieldLabel extends StatelessWidget {
  final String text;
  final FieldRequirement requirement;
  final bool enabled;

  const FieldLabel(
    this.text, {
    super.key,
    this.requirement = FieldRequirement.none,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? AppColors.textSecondaryDark
        : AppColors.textDisabledDark;
    final semantic = switch (requirement) {
      FieldRequirement.required => '$text, obrigatório',
      FieldRequirement.optional => '$text, opcional',
      FieldRequirement.none => text,
    };
    return Semantics(
      label: semantic,
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          text: text,
          children: [
            if (requirement == FieldRequirement.required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: AppColors.primary),
              ),
            if (requirement == FieldRequirement.optional)
              const TextSpan(
                text: ' (opcional)',
                style: TextStyle(
                  color: AppColors.textMutedDark,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Legenda curta no topo de formulários que usam [FieldRequirement.required].
class RequiredFieldsNote extends StatelessWidget {
  const RequiredFieldsNote({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '*',
            style: TextStyle(color: AppColors.primary),
          ),
          TextSpan(text: ' indica campo obrigatório.'),
        ],
      ),
      style: TextStyle(color: AppColors.textMutedDark, fontSize: 12),
    );
  }
}
