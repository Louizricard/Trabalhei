import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';

/// "Manter conectado" e "Esqueceu a senha?" na mesma linha do login.
class KeepSignedInRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const KeepSignedInRow({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 4,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onChanged(!value),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: value,
                activeColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
                onChanged: (v) => onChanged(v ?? true),
              ),
              const Text(
                'Manter conectado',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => context.push('/forgot-password'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Esqueceu a senha?'),
        ),
      ],
    );
  }
}
