import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../../auth/presentation/guest_access.dart';

/// Cidade, links e currículo do perfil, em chips. Não aparece se vazio.
class ProfileLinks extends ConsumerWidget {
  final UserProfile profile;

  const ProfileLinks({super.key, required this.profile});

  static bool hasContent(UserProfile p) => [
    p.location,
    p.websiteUrl,
    p.linkedinUrl,
    p.githubUrl,
    p.resumeUrl,
  ].any((v) => v != null && v.trim().isNotEmpty);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!hasContent(profile)) return const SizedBox.shrink();
    Widget link(
      IconData icon,
      String label,
      String? url, {
      bool private = false,
    }) {
      if (url == null || url.isEmpty) return const SizedBox.shrink();
      return _Chip(
        icon: icon,
        label: label,
        onTap: () async {
          if (!private) {
            await launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            );
          } else if (await requireAccount(
            context,
            ref,
            action: 'ver o currículo',
          )) {
            await ref.read(storageServiceProvider).launchAttachment(url);
          }
        },
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (profile.location?.isNotEmpty == true)
          _Chip(icon: Icons.place_outlined, label: profile.location!),
        link(Icons.language_rounded, 'Site', profile.websiteUrl),
        link(Icons.work_outline_rounded, 'LinkedIn', profile.linkedinUrl),
        link(Icons.terminal_rounded, 'GitHub', profile.githubUrl),
        link(
          Icons.picture_as_pdf_outlined,
          'Currículo',
          profile.resumeUrl,
          private: true,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _Chip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final clickable = onTap != null;
    return Material(
      color: AppColors.surfaceElevatedDark,
      shape: StadiumBorder(
        side: BorderSide(
          color: clickable
              ? AppColors.primary.withAlpha(90)
              : AppColors.borderDark,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: clickable
                    ? AppColors.primary
                    : AppColors.textSecondaryDark,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: clickable
                        ? AppColors.textPrimaryDark
                        : AppColors.textSecondaryDark,
                  ),
                ),
              ),
              if (clickable) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.open_in_new_rounded,
                  size: 13,
                  color: AppColors.textMutedDark,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
