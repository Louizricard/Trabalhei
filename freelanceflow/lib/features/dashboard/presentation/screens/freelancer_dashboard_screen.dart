import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freelanceflow/core/theme/app_colors.dart';
import 'package:freelanceflow/core/utils/currency_formatter.dart';
import 'package:freelanceflow/core/widgets/custom_button.dart';
import 'package:freelanceflow/core/widgets/empty_state.dart';
import 'package:freelanceflow/core/widgets/glass_card.dart';
import 'package:freelanceflow/core/widgets/responsive_layout.dart';
import 'package:freelanceflow/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:freelanceflow/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:freelanceflow/features/dashboard/presentation/widgets/earnings_chart.dart';
import 'package:go_router/go_router.dart';

class FreelancerDashboardScreen extends ConsumerWidget {
  const FreelancerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(freelancerStatsProvider);
    final user = ref.watch(authProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Freelancer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Minha Carteira',
            onPressed: () => context.push('/payments'),
          ),
        ],
      ),
      body: ResponsiveLayout(
        child: statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => EmptyStateWidget(
            icon: Icons.error_outline_rounded,
            title: 'Erro ao carregar dashboard',
            description: err.toString(),
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
                            user?.fullName.substring(0, 1).toUpperCase() ?? 'F',
                            style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Olá, ${user?.fullName ?? 'Freelancer'} 👋',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Job Success Score: ${stats.jobSuccessScore}% • 18 Projetos Concluídos',
                                style: const TextStyle(fontSize: 12, color: AppColors.primaryLight, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GlassCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.lock_clock_outlined, size: 18, color: AppColors.info),
                                  SizedBox(width: 6),
                                  Text('Em Escrow (Garantido)', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                CurrencyFormatter.format(stats.escrowBalance),
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.info),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GlassCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
                                  SizedBox(width: 6),
                                  Text('Saldo Disponível', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                CurrencyFormatter.format(stats.availableBalance),
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.success),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: 'Solicitar Saque Instantâneo via Pix',
                    icon: Icons.pix_rounded,
                    width: double.infinity,
                    onPressed: () => context.push('/payments'),
                  ),
                  const SizedBox(height: 20),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Evolução do Faturamento',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
                            ),
                            Text(
                              'Total mês: ${CurrencyFormatter.format(stats.monthlyEarnings)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        EarningsChart(data: stats.monthlyChartData),
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
