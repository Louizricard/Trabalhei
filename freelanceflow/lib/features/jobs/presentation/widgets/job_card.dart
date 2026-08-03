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

  const JobCard({super.key, required this.job, this.onTap});

  @override
  Widget build(BuildContext context) {
    final budgetText = job.contractType == ContractType.fixed
        ? CurrencyFormatter.formatRange(job.budgetMin, job.budgetMax)
        : '${CurrencyFormatter.format(job.budgetMin)} - ${CurrencyFormatter.format(job.budgetMax)}/h';

    return GlassCard(
      padding: const EdgeInsets.all(18),
      onTap: onTap ?? () => context.push('/jobs/${job.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryDark),
                ),
              ),
              const Spacer(),
              Text(
                DateFormatter.relativeTime(job.createdAt),
                style: const TextStyle(fontSize: 12, color: AppColors.textMutedDark),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            job.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryDark,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            job.description,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondaryDark,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          if (job.skillsRequired.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: job.skillsRequired.take(4).map((skill) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primary.withAlpha(50)),
                  ),
                  child: Text(
                    skill,
                    style: const TextStyle(fontSize: 11, color: AppColors.primaryLight),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
          ],
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.contractType == ContractType.fixed ? 'Orçamento Estimado' : 'Valor por Hora',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMutedDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    budgetText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.description_outlined, size: 14, color: AppColors.textSecondaryDark),
                  const SizedBox(width: 4),
                  Text(
                    '${job.proposalsCount} propostas',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.star_rounded, size: 16, color: AppColors.warning),
                  const SizedBox(width: 2),
                  Text(
                    job.clientRating.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
