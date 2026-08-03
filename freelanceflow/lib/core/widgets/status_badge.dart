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
        backgroundColor: Color(0xFF064E3B),
        textColor: AppColors.success,
        icon: Icons.check_circle_outline,
      );

  factory StatusBadge.inProgress() => const StatusBadge(
        label: 'Em Andamento',
        backgroundColor: Color(0xFF0C4A6E),
        textColor: AppColors.info,
        icon: Icons.sync,
      );

  factory StatusBadge.completed() => const StatusBadge(
        label: 'Concluído',
        backgroundColor: Color(0xFF1E1B4B),
        textColor: AppColors.primaryLight,
        icon: Icons.verified,
      );

  factory StatusBadge.escrowHold() => const StatusBadge(
        label: 'Escrow Garantido',
        backgroundColor: Color(0xFF1E3A8A),
        textColor: Color(0xFF60A5FA),
        icon: Icons.shield_outlined,
      );

  factory StatusBadge.urgent() => const StatusBadge(
        label: 'Urgente',
        backgroundColor: Color(0xFF7F1D1D),
        textColor: AppColors.error,
        icon: Icons.local_fire_department,
      );

  factory StatusBadge.featured() => const StatusBadge(
        label: 'Destaque',
        backgroundColor: Color(0xFF78350F),
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
        border: Border.all(color: textColor.withAlpha(50), width: 1),
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
