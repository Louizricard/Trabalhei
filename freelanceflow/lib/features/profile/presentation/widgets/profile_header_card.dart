import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/rating_formatter.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/domain/entities/user_profile.dart';

/// Cabeçalho do "Meu Perfil": identidade, reputação e ações principais.
class ProfileHeaderCard extends StatelessWidget {
  final UserProfile user;
  final bool isUploadingAvatar;
  final VoidCallback onPickAvatar;
  final VoidCallback onEditProfile;
  final VoidCallback onViewPublicProfile;

  const ProfileHeaderCard({
    super.key,
    required this.user,
    required this.isUploadingAvatar,
    required this.onPickAvatar,
    required this.onEditProfile,
    required this.onViewPublicProfile,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Avatar(
                user: user,
                isUploading: isUploadingAvatar,
                onPick: onPickAvatar,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryDark,
                            ),
                          ),
                        ),
                        if (user.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Badge(
                          label: user.role.label,
                          color: AppColors.primary,
                        ),
                        _Badge(
                          label: user.isPro ? 'Plano Pro' : 'Plano Grátis',
                          color: user.isPro
                              ? AppColors.warning
                              : AppColors.textSecondaryDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevatedDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _Stat(
                  value: RatingFormatter.format(user.rating),
                  label: 'Nota',
                  icon: Icons.star_rounded,
                ),
                const _StatDivider(),
                _Stat(value: '${user.reviewsCount}', label: 'Avaliações'),
                const _StatDivider(),
                _Stat(
                  value: '${user.completedJobsCount}',
                  label: 'Projetos concluídos',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final edit = CustomButton(
                text: 'Editar perfil',
                icon: Icons.edit_rounded,
                onPressed: onEditProfile,
              );
              final viewPublic = CustomButton(
                text: 'Ver perfil público',
                variant: ButtonVariant.outline,
                icon: Icons.visibility_outlined,
                onPressed: onViewPublicProfile,
              );
              // Telas estreitas: um botão por linha, sem cortar o texto.
              if (constraints.maxWidth < 360) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [edit, const SizedBox(height: 10), viewPublic],
                );
              }
              return Row(
                children: [
                  Expanded(child: edit),
                  const SizedBox(width: 10),
                  Expanded(child: viewPublic),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final UserProfile user;
  final bool isUploading;
  final VoidCallback onPick;

  const _Avatar({
    required this.user,
    required this.isUploading,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = user.avatarUrl != null && user.avatarUrl!.isNotEmpty;
    return Stack(
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: AppColors.primary,
          backgroundImage: hasPhoto ? NetworkImage(user.avatarUrl!) : null,
          child: hasPhoto
              ? null
              : Text(
                  user.fullName.isNotEmpty
                      ? user.fullName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimary,
                  ),
                ),
        ),
        if (isUploading)
          Positioned.fill(
            child: CircleAvatar(
              backgroundColor: AppColors.bgDark.withAlpha(180),
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
          )
        else
          Positioned(
            bottom: 0,
            right: 0,
            child: Material(
              color: AppColors.primary,
              shape: const CircleBorder(
                side: BorderSide(color: AppColors.cardDark, width: 2),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPick,
                child: const Padding(
                  padding: EdgeInsets.all(5),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    size: 14,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;

  const _Stat({required this.value, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppColors.warning),
                const SizedBox(width: 3),
              ],
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: AppColors.borderDark);
  }
}
