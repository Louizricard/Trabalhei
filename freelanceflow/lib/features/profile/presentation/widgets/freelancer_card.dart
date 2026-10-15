import 'package:freelanceflow/core/utils/rating_formatter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/domain/entities/user_profile.dart';

class FreelancerCard extends StatelessWidget {
  final UserProfile freelancer;
  final VoidCallback? onInvitePressed;

  const FreelancerCard({
    super.key,
    required this.freelancer,
    this.onInvitePressed,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = freelancer.availabilityStatus == 'available';

    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Nome, Disponibilidade e Preço
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar com badge de disponibilidade
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primaryContainer,
                    backgroundImage:
                        freelancer.avatarUrl != null &&
                            freelancer.avatarUrl!.isNotEmpty
                        ? NetworkImage(freelancer.avatarUrl!)
                        : null,
                    child:
                        freelancer.avatarUrl == null ||
                            freelancer.avatarUrl!.isEmpty
                        ? Text(
                            freelancer.fullName.trim().isNotEmpty
                                ? freelancer.fullName.trim()[0].toUpperCase()
                                : 'F',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? AppColors.success
                            : AppColors.warning,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.surfaceDark,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Informações principais
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            freelancer.fullName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryDark,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (freelancer.isPro) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PRO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                        if (freelancer.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            color: AppColors.primary,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      freelancer.skills.isNotEmpty
                          ? freelancer.skills.take(2).join(' • ')
                          : 'Especialista Freelancer',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondaryDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Rating & Jobs entregues
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.warning,
                          size: 16,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          RatingFormatter.format(freelancer.rating),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•  ${freelancer.completedJobsCount} ${freelancer.completedJobsCount == 1 ? "projeto" : "projetos"}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMutedDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Valor / hora
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(freelancer.hourlyRate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const Text(
                    '/hora',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMutedDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Bio resumida se existir
          if (freelancer.bio != null && freelancer.bio!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              freelancer.bio!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryDark,
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Tags de Skills
          if (freelancer.skills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: freelancer.skills.take(4).map((skill) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevatedDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.borderDark.withAlpha(128),
                    ),
                  ),
                  child: Text(
                    skill,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.borderDark),
          const SizedBox(height: 12),

          // Botões de Ação
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimaryDark,
                    side: const BorderSide(color: AppColors.borderDark),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.person_outline_rounded, size: 16),
                  label: const Text(
                    'Ver Perfil',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => context.push('/profile/${freelancer.id}'),
                ),
              ),
              if (onInvitePressed != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 15),
                    label: const Text(
                      'Convidar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: onInvitePressed,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
