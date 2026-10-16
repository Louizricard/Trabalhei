import 'package:freelanceflow/core/errors/backend_errors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../jobs/presentation/providers/jobs_provider.dart';
import '../providers/profile_provider.dart';

import 'package:image_picker/image_picker.dart';
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
        context.go(
          targetRole == UserRole.client ? '/dashboard' : '/jobs',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Falha ao alternar modo: ${friendlyError(e)}',
            ),
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
            content: Text(
              'Erro ao enviar foto: ${friendlyError(e)}',
            ),
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
    final user = ref.watch(authProvider).value;
    final reviewsAsync = ref.watch(userReviewsProvider);
    final isFreelancer = user?.role == UserRole.freelancer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            tooltip: 'Sair da Conta',
            onPressed: () {
              ref.read(authProvider.notifier).signOut();
              context.go('/login');
            },
          ),
        ],
      ),
      body: ResponsiveLayout(
        maxWidth: 800,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: AppColors.primary,
                          backgroundImage:
                              (user?.avatarUrl != null &&
                                  user!.avatarUrl!.isNotEmpty)
                              ? NetworkImage(user.avatarUrl!)
                              : null,
                          child:
                              (user?.avatarUrl == null ||
                                  user!.avatarUrl!.isEmpty)
                              ? Text(
                                  (user?.fullName.isNotEmpty ?? false)
                                      ? user!.fullName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onPrimary,
                                  ),
                                )
                              : null,
                        ),
                        if (_isUploadingAvatar)
                          Positioned.fill(
                            child: CircleAvatar(
                              backgroundColor: AppColors.bgDark.withAlpha(180),
                              child: const SizedBox(
                                width: 24,
                                height: 24,
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
                            child: GestureDetector(
                              onTap: _pickAndUploadAvatar,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 16,
                                  color: AppColors.onPrimary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          user?.fullName ?? 'Usuário',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryDark,
                          ),
                        ),
                        if (user?.isVerified ?? false) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withAlpha(60),
                        ),
                      ),
                      child: Text(
                        user?.role.label ?? 'Freelancer',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Editar Perfil',
                            icon: Icons.edit_rounded,
                            onPressed: () {
                              if (user == null) return;
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: AppColors.transparent,
                                isScrollControlled: true,
                                builder: (_) => EditProfileModal(user: user),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CustomButton(
                            text: isFreelancer
                                ? 'Modo Contratante'
                                : 'Modo Freelancer',
                            variant: ButtonVariant.secondary,
                            icon: Icons.swap_horiz_rounded,
                            isLoading: _isSwitchingRole,
                            onPressed: _isSwitchingRole
                                ? null
                                : () => _handleSwitchRole(isFreelancer),
                          ),
                        ),
                      ],
                    ),
                    if (user != null) ...[
                      const SizedBox(height: 10),
                      CustomButton(
                        text: 'Visualizar como Perfil Público',
                        variant: ButtonVariant.outline,
                        icon: Icons.visibility_outlined,
                        width: double.infinity,
                        onPressed: () => context.push('/profile/${user.id}'),
                      ),
                      const SizedBox(height: 10),
                      CustomButton(
                        text: user.isPro ? 'Meu Plano: Pro' : 'Meu Plano: Grátis',
                        variant: ButtonVariant.outline,
                        icon: Icons.workspace_premium_outlined,
                        width: double.infinity,
                        onPressed: () => context.push('/plans'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sobre Mim',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user?.bio?.isNotEmpty == true
                          ? user!.bio!
                          : 'Sem biografia cadastrada.',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                    if (isFreelancer && (user?.hourlyRate ?? 0) > 0) ...[
                      const Divider(height: 20),
                      Row(
                        children: [
                          const Text(
                            'Valor Hora Sugerido:',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                          const SizedBox(width: 8),
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
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (user != null && user.skills.isNotEmpty) ...[
                const Text(
                  'Especialidades & Habilidades',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: user.skills.map((skill) {
                    return Chip(
                      label: Text(skill),
                      backgroundColor: AppColors.surfaceElevatedDark,
                      labelStyle: const TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],
              const Text(
                'Avaliações & Reputação',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              reviewsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (_, _) => const Text(
                  'Não foi possível carregar as avaliações.',
                  style: TextStyle(color: AppColors.textMutedDark),
                ),
                data: (reviews) {
                  if (reviews.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Nenhuma avaliação recebida ainda.',
                        style: TextStyle(
                          color: AppColors.textMutedDark,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: reviews.map((rev) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    rev.authorName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Row(
                                    children: [
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
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                rev.comment,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton.icon(
                  icon: const Icon(
                    Icons.policy_outlined,
                    size: 16,
                    color: AppColors.textMutedDark,
                  ),
                  label: const Text(
                    'Termos de Uso e Política de Privacidade',
                    style: TextStyle(
                      color: AppColors.textMutedDark,
                      fontSize: 12,
                    ),
                  ),
                  onPressed: () => context.push('/terms'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
