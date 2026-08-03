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
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        (user?.fullName.isNotEmpty ?? false) ? user!.fullName[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          user?.fullName ?? 'Usuário',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
                        ),
                        if (user?.isVerified ?? false) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, size: 18, color: AppColors.primaryLight),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryDark),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withAlpha(60)),
                      ),
                      child: Text(
                        user?.role.label ?? 'Freelancer',
                        style: const TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      text: isFreelancer ? 'Alternar para Modo Contratante' : 'Alternar para Modo Freelancer',
                      variant: ButtonVariant.secondary,
                      icon: Icons.swap_horiz_rounded,
                      onPressed: () {
                        ref.read(authProvider.notifier).switchRole(
                              isFreelancer ? UserRole.client : UserRole.freelancer,
                            );
                        context.go(isFreelancer ? '/dashboard/client' : '/jobs');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sobre Mim', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    Text(
                      user?.bio?.isNotEmpty == true ? user!.bio! : 'Sem biografia cadastrada.',
                      style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondaryDark),
                    ),
                    if (isFreelancer && (user?.hourlyRate ?? 0) > 0) ...[
                      const Divider(height: 20),
                      Row(
                        children: [
                          const Text('Valor Hora Sugerido:', style: TextStyle(fontSize: 13, color: AppColors.textSecondaryDark)),
                          const SizedBox(width: 8),
                          Text(
                            '${CurrencyFormatter.format(user!.hourlyRate)}/h',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.success),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (user != null && user.skills.isNotEmpty) ...[
                const Text('Especialidades & Habilidades', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: user.skills.map((skill) {
                    return Chip(
                      label: Text(skill),
                      backgroundColor: AppColors.surfaceElevatedDark,
                      labelStyle: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 12),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],
              const Text('Avaliações & Reputação', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              reviewsAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
                error: (_, _) => const Text('Não foi possível carregar as avaliações.', style: TextStyle(color: AppColors.textMutedDark)),
                data: (reviews) {
                  if (reviews.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Nenhuma avaliação recebida ainda.', style: TextStyle(color: AppColors.textMutedDark, fontSize: 13)),
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(rev.authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded, size: 16, color: AppColors.warning),
                                      const SizedBox(width: 2),
                                      Text(rev.rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(rev.comment, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
