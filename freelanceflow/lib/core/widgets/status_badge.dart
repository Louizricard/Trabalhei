import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  });

  factory StatusBadge.open() => const StatusBadge(
    label: 'Aberto',
    backgroundColor: AppColors.successBg,
    textColor: AppColors.success,
    icon: Icons.check_circle_outline_rounded,
  );

  factory StatusBadge.inProgress() => const StatusBadge(
    label: 'Em Andamento',
    backgroundColor: AppColors.infoBg,
    textColor: AppColors.info,
    icon: Icons.sync_rounded,
  );

  factory StatusBadge.completed() => const StatusBadge(
    label: 'Concluído',
    backgroundColor: AppColors.primaryContainer,
    textColor: AppColors.primary,
    icon: Icons.verified_rounded,
  );

  factory StatusBadge.urgent() => const StatusBadge(
    label: 'Urgente',
    backgroundColor: AppColors.errorBg,
    textColor: AppColors.error,
    icon: Icons.local_fire_department_rounded,
  );

  /// Vaga com destaque pago: sempre identificada como patrocinada.
  factory StatusBadge.featured() => const StatusBadge(
    label: 'Patrocinado',
    backgroundColor: AppColors.warningBg,
    textColor: AppColors.warning,
    icon: Icons.star_rounded,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
