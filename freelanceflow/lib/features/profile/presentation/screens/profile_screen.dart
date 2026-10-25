import 'package:trabalhei/core/errors/backend_errors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../jobs/presentation/providers/jobs_provider.dart';
import '../providers/profile_provider.dart';

import 'package:image_picker/image_picker.dart';
import '../widgets/delete_account_button.dart';
import '../widgets/profile_header_card.dart';
import '../widgets/profile_settings.dart';
import '../widgets/edit_profile_modal.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploadingAvatar = false;
  bool _isSwitchingRole = false;

  Future<void> _handleSwitchRole(bool isFreelancer) async {
    final targetRole = isFreelancer ? UserRole.client : UserRole.freelancer;
    setState(() => _isSwitchingRole = true);

    try {
      await ref.read(authProvider.notifier).switchRole(targetRole);
      ref.invalidate(clientStatsProvider);
      ref.invalidate(freelancerStatsProvider);
      ref.invalidate(jobsListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alternado para ${targetRole.label} com sucesso!'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
        context.go(targetRole == UserRole.client ? '/dashboard' : '/jobs');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao alternar modo: ${friendlyError(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSwitchingRole = false);
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() => _isUploadingAvatar = true);

      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last.toLowerCase();

      final uploadFn = ref.read(uploadAvatarProvider);
      await uploadFn(bytes, ext.isEmpty ? 'jpg' : ext);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto de perfil atualizada com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar foto: ${friendlyError(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final reviewsAsync = ref.watch(userReviewsProvider);
    final isFreelancer = user?.role == UserRole.freelancer;

    return Scaffold(
      appBar: AppBar(title: const Text('Meu Perfil')),
      body: ResponsiveLayout(
        maxWidth: 800,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (user != null)
                ProfileHeaderCard(
                  user: user,
                  isUploadingAvatar: _isUploadingAvatar,
                  onPickAvatar: _pickAndUploadAvatar,
                  onEditProfile: () => showModalBottomSheet(
                    context: context,
                    backgroundColor: AppColors.transparent,
                    isScrollControlled: true,
                    builder: (_) => EditProfileModal(user: user),
                  ),
                  onViewPublicProfile: () =>
                      context.push('/profile/${user.id}'),
                ),
              const SizedBox(height: 24),
              const _SectionTitle('Sobre mim'),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.bio?.isNotEmpty == true
                          ? user!.bio!
                          : 'Você ainda não escreveu sua biografia. Toque em '
                                '"Editar perfil" para se apresentar.',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                    if (isFreelancer && (user?.hourlyRate ?? 0) > 0) ...[
                      const Divider(height: 24, color: AppColors.borderDark),
                      Row(
                        children: [
                          const Text(
                            'Valor por hora',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${CurrencyFormatter.format(user!.hourlyRate)}/h',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (user != null && user.skills.isNotEmpty) ...[
                      const Divider(height: 24, color: AppColors.borderDark),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final skill in user.skills)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(25),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.primary.withAlpha(50),
                                ),
                              ),
                              child: Text(
                                skill,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Avaliações recebidas'),
              reviewsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (_, _) => const _MutedCard(
                  'Não foi possível carregar as avaliações.',
                ),
                data: (reviews) {
                  if (reviews.isEmpty) {
                    return const _MutedCard(
                      'Nenhuma avaliação ainda. Elas aparecem aqui quando um '
                      'contrato é concluído.',
                    );
                  }
                  return Column(
                    children: [
                      for (final rev in reviews)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GlassCard(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        rev.authorName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 16,
                                      color: AppColors.warning,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      rev.rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                if (rev.comment.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    rev.comment,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: AppColors.textSecondaryDark,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              ProfileSettingsGroup(
                title: 'Conta',
                children: [
                  ProfileSettingsTile(
                    icon: Icons.swap_horiz_rounded,
                    title: isFreelancer
                        ? 'Usar como contratante'
                        : 'Usar como freelancer',
                    subtitle: isFreelancer
                        ? 'Publique vagas e contrate profissionais'
                        : 'Envie propostas e trabalhe em projetos',
                    isLoading: _isSwitchingRole,
                    onTap: () => _handleSwitchRole(isFreelancer),
                  ),
                  ProfileSettingsTile(
                    icon: Icons.workspace_premium_outlined,
                    title: 'Meu plano',
                    subtitle: user?.isPro == true
                        ? 'Pro: propostas ilimitadas'
                        : 'Grátis: conheça o plano Pro',
                    onTap: () => context.push('/plans'),
                  ),
                  ProfileSettingsTile(
                    icon: Icons.policy_outlined,
                    title: 'Termos de Uso e Privacidade',
                    onTap: () => context.push('/terms'),
                  ),
                  ProfileSettingsTile(
                    icon: Icons.logout_rounded,
                    title: 'Sair da conta',
                    trailing: const SizedBox.shrink(),
                    onTap: () {
                      ref.read(authProvider.notifier).signOut();
                      context.go('/login');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const ProfileSettingsGroup(
                title: 'Zona de risco',
                children: [DeleteAccountButton()],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimaryDark,
        ),
      ),
    );
  }
}

class _MutedCard extends StatelessWidget {
  final String text;

  const _MutedCard(this.text);

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.textMutedDark, fontSize: 13),
      ),
    );
  }
}
