import 'package:trabalhei/core/errors/backend_errors.dart';
import 'package:trabalhei/features/dashboard/presentation/widgets/profile_checklist_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trabalhei/core/theme/app_colors.dart';
import 'package:trabalhei/core/widgets/custom_button.dart';
import 'package:trabalhei/core/widgets/empty_state.dart';
import 'package:trabalhei/core/widgets/glass_card.dart';
import 'package:trabalhei/core/widgets/responsive_layout.dart';
import 'package:trabalhei/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:trabalhei/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:trabalhei/features/dashboard/presentation/widgets/activity_chart.dart';
import 'package:trabalhei/features/dashboard/presentation/widgets/dashboard_stat_card.dart';
import 'package:trabalhei/features/dashboard/presentation/widgets/pro_tools_card.dart';
import 'package:go_router/go_router.dart';

class FreelancerDashboardScreen extends ConsumerWidget {
  const FreelancerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(freelancerStatsProvider);
    final user = ref.watch(authProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Painel do freelancer')),
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
                                : 'F',
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
                                'Olá, ${user?.fullName ?? 'Freelancer'} 👋',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimaryDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Taxa de sucesso: ${stats.proposalSuccessRate.toStringAsFixed(0)}% • ${stats.completedContractsCount} projeto(s) concluído(s)',
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
                  if (user != null) ProfileChecklistCard(user: user),
                  Row(
                    children: [
                      Expanded(
                        child: DashboardStatCard(
                          icon: Icons.handshake_outlined,
                          color: AppColors.success,
                          label: 'Contratos ativos',
                          value: '${stats.activeContractsCount}',
                          onTap: () => context.go('/chat'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DashboardStatCard(
                          icon: Icons.hourglass_top_rounded,
                          color: AppColors.info,
                          label: 'Propostas pendentes',
                          value: '${stats.pendingProposalsCount}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    key: const Key('dashboard-find-jobs'),
                    text: 'Encontrar vagas',
                    icon: Icons.search_rounded,
                    width: double.infinity,
                    onPressed: () => context.go('/jobs'),
                  ),
                  const SizedBox(height: 20),
                  ProToolsCard(isPro: user?.isPro ?? false),
                  const SizedBox(height: 20),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Trabalhos concluídos por mês',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ActivityChart(data: stats.monthlyCompleted),
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
