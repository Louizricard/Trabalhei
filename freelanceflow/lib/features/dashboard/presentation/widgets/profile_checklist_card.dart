import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../domain/profile_checklist.dart';

/// Primeiros passos no painel. Some quando tudo estiver feito.
class ProfileChecklistCard extends StatelessWidget {
  final UserProfile user;
  final bool hasJobs;

  const ProfileChecklistCard({
    super.key,
    required this.user,
    this.hasJobs = false,
  });

  @override
  Widget build(BuildContext context) {
    final steps = profileChecklist(user, hasJobs: hasJobs);
    final done = steps.where((s) => s.done).length;
    if (done == steps.length) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.role == UserRole.client
                  ? 'Comece a contratar'
                  : 'Complete seu perfil',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              user.role == UserRole.client
                  ? 'Perfis completos recebem propostas mais rápido.'
                  : 'Perfis completos aparecem melhor na busca de talentos.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMutedDark,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: done / steps.length,
              semanticsLabel: '$done de ${steps.length} passos concluídos',
            ),
            const SizedBox(height: 8),
            for (final step in steps) _StepTile(step: step),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final ChecklistStep step;

  const _StepTile({required this.step});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        step.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
        color: step.done ? AppColors.success : AppColors.textMutedDark,
      ),
      title: Text(
        step.label,
        style: TextStyle(
          decoration: step.done ? TextDecoration.lineThrough : null,
          color: step.done
              ? AppColors.textMutedDark
              : AppColors.textPrimaryDark,
        ),
      ),
      trailing: step.done ? null : const Icon(Icons.chevron_right_rounded),
      onTap: step.done ? null : () => context.push(step.route),
    );
  }
}
