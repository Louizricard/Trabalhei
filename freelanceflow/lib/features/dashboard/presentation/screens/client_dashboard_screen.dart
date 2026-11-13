import 'package:trabalhei/core/errors/backend_errors.dart';
import 'package:trabalhei/features/dashboard/presentation/widgets/profile_checklist_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/dashboard_stat_card.dart';

class ClientDashboardScreen extends ConsumerWidget {
  const ClientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(clientStatsProvider);
    final user = ref.watch(authProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Painel do contratante')),
      body: ResponsiveLayout(
        child: statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => EmptyStateWidget(
            icon: Icons.error_outline_rounded,
            title: 'Erro ao carregar o painel',
            description: friendlyError(err),
          ),
          data: (stats) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            (user?.fullName.trim().isNotEmpty ?? false)
                                ? user!.fullName.trim()[0].toUpperCase()
                                : 'C',
                            style: const TextStyle(
                              fontSize: 18,
                              color: AppColors.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.companyName ??
                                    user?.fullName ??
                                    'Contratante',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimaryDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${stats.completedContractsCount} projeto(s) concluído(s)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primaryLight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (user != null)
                    ProfileChecklistCard(
                      user: user,
                      hasJobs:
                          stats.activeJobsCount +
                              stats.activeContractsCount +
                              stats.completedContractsCount >
                          0,
                    ),

                  Row(
                    children: [
                      Expanded(
                        child: DashboardStatCard(
                          icon: Icons.mark_email_unread_outlined,
                          label: 'Propostas p/ analisar',
                          value: '${stats.unreviewedProposalsCount}',
                          color: AppColors.info,
                          onTap: () =>
                              context.go('/jobs', extra: 'Minhas Vagas'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DashboardStatCard(
                          icon: Icons.task_alt_rounded,
                          label: 'Contratos concluídos',
                          value: '${stats.completedContractsCount}',
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Ações principais: buscar talentos e publicar vaga
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: 'Buscar Talentos',
                          icon: Icons.people_outline_rounded,
                          variant: ButtonVariant.primary,
                          onPressed: () => context.push('/freelancers'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          text: 'Publicar Vaga',
                          icon: Icons.add_circle_outline_rounded,
                          variant: ButtonVariant.secondary,
                          onPressed: () => context.push('/jobs/create'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Gestão de Talentos e Vagas
                  GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Suas vagas e contratos',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.surfaceElevatedDark,
                            child: Icon(
                              Icons.work_outline,
                              color: AppColors.primaryLight,
                            ),
                          ),
                          title: Text(
                            '${stats.activeJobsCount} Vagas Abertas no Mural',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: const Text(
                            'Recebendo candidaturas e propostas',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMutedDark,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textSecondaryDark,
                          ),
                          onTap: () =>
                              context.go('/jobs', extra: 'Minhas Vagas'),
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.surfaceElevatedDark,
                            child: Icon(
                              Icons.handshake_outlined,
                              color: AppColors.success,
                            ),
                          ),
                          title: Text(
                            '${stats.activeContractsCount} Contratos em Andamento',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: const Text(
                            'Acompanhe entregas e aprovação de marcos',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMutedDark,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textSecondaryDark,
                          ),
                          onTap: () => context.go('/chat'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
