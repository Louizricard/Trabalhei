import 'package:freelanceflow/core/utils/rating_formatter.dart';
import 'package:flutter/material.dart';
import 'package:freelanceflow/core/theme/app_colors.dart';
import 'package:freelanceflow/core/utils/currency_formatter.dart';
import 'package:freelanceflow/core/utils/date_formatter.dart';
import 'package:freelanceflow/core/widgets/glass_card.dart';
import 'package:freelanceflow/core/widgets/status_badge.dart';
import 'package:freelanceflow/features/jobs/domain/entities/job.dart';
import 'package:go_router/go_router.dart';

class JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback? onTap;
  final bool userHasApplied;
  final VoidCallback? onApply;
  final VoidCallback? onMessage;
  final bool isOwner;
  final VoidCallback? onEdit;

  const JobCard({
    super.key,
    required this.job,
    this.onTap,
    this.userHasApplied = false,
    this.onApply,
    this.onMessage,
    this.isOwner = false,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final budgetText = job.contractType == ContractType.fixed
        ? CurrencyFormatter.formatRange(job.budgetMin, job.budgetMax)
        : '${CurrencyFormatter.format(job.budgetMin)} - ${CurrencyFormatter.format(job.budgetMax)}/h';

    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: onTap ?? () => context.push('/jobs/${job.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Image or Placeholder
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: job.imageUrl != null && job.imageUrl!.isNotEmpty
                ? Image.network(
                    job.imageUrl!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
          ),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges
                Row(
                  children: [
                    if (job.isUrgent) ...[
                      StatusBadge.urgent(),
                      const SizedBox(width: 6),
                    ],
                    if (job.isFeatured) ...[
                      StatusBadge.featured(),
                      const SizedBox(width: 6),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevatedDark,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        job.category,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormatter.relativeTime(job.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMutedDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Title
                Text(
                  job.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                
                // Description
                Text(
                  job.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryDark,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                
                // Tags / Skills
                if (job.skillsRequired.isNotEmpty) ...[
                  SizedBox(
                    height: 26,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: job.skillsRequired.length > 4 ? 4 : job.skillsRequired.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final skill = job.skillsRequired[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(25),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.primary.withAlpha(50)),
                          ),
                          child: Center(
                            child: Text(
                              skill,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primaryLight,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Spacer(),
                const Divider(height: 1),
                const SizedBox(height: 12),
                
                // Budget and Secondary Info
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.contractType == ContractType.fixed
                                ? 'Orçamento Estimado'
                                : 'Valor por Hora',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMutedDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              budgetText,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          size: 14,
                          color: AppColors.textSecondaryDark,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${job.proposalsCount} propostas',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          RatingFormatter.format(job.clientRating),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Actions
                if (isOwner) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: onEdit ?? () => context.push('/jobs/${job.id}/edit', extra: job),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text(
                        'Editar Vaga',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryLight,
                        side: BorderSide(color: AppColors.primary.withAlpha(100)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: onApply ?? () => context.push('/jobs/${job.id}/apply'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Enviar proposta',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (userHasApplied) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: onMessage ?? () {}, // Handle chat routing in parent
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                        label: const Text(
                          'Enviar mensagem',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryLight,
                          side: BorderSide(color: AppColors.primary.withAlpha(100)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF132B47),
            Color(0xFF19E6A7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.work_outline_rounded,
          size: 48,
          color: AppColors.surfaceDark.withAlpha(150),
        ),
      ),
    );
  }
}
