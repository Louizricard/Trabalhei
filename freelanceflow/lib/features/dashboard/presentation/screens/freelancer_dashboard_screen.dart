import 'package:trabalhei/core/errors/backend_errors.dart';
import 'package:flutter/material.dart';
import '../../../billing/presentation/widgets/pro_upsell.dart';
import 'pro_tools_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trabalhei/core/theme/app_colors.dart';
import 'package:trabalhei/core/widgets/empty_state.dart';
import 'package:trabalhei/core/widgets/glass_card.dart';
import 'package:trabalhei/core/widgets/responsive_layout.dart';
import 'package:trabalhei/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:trabalhei/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:trabalhei/features/dashboard/presentation/widgets/activity_chart.dart';
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
            icon: const Icon(Icons.workspace_premium_outlined),
            tooltip: 'Planos',
            onPressed: () => context.push('/plans'),
          ),
        ],
      ),
      body: ResponsiveLayout(
        child: statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => EmptyStateWidget(
            icon: Icons.error_outline_rounded,
            title: 'Erro ao carregar dashboard',
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
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.handshake_outlined,
                          color: AppColors.success,
                          label: 'Contratos ativos',
                          value: '${stats.activeContractsCount}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.hourglass_top_rounded,
                          color: AppColors.info,
                          label: 'Propostas pendentes',
                          value: '${stats.pendingProposalsCount}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _ProTools(isPro: user?.isPro ?? false),
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
                              'Projetos concluídos por mês',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimaryDark,
                              ),
                            ),
                          ],
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ferramentas do plano Pro. No grátis, o toque explica o recurso e leva aos
/// planos.
class _ProTools extends StatelessWidget {
  final bool isPro;
  const _ProTools({required this.isPro});

  @override
  Widget build(BuildContext context) {
    final tools = [
      (
        Icons.insights_rounded,
        'Estatísticas das propostas',
        'Aceite, tempo de resposta e valores',
        '/pro/stats',
        statsUpsell,
      ),
      (
        Icons.groups_2_outlined,
        'Clientes e projetos',
        'Histórico e anotações por cliente',
        '/pro/clients',
        clientsUpsell,
      ),
      (
        Icons.content_paste_rounded,
        'Modelos de proposta',
        'Cartas e prazos prontos para reutilizar',
        '/pro/templates',
        'Salve cartas de apresentação e prazos que você usa sempre e aplique em um toque.',
      ),
    ];
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 16, 4),
            child: Row(
              children: [
                const Text(
                  'Ferramentas Pro',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(width: 8),
                if (!isPro) const ProBadge(),
              ],
            ),
          ),
          for (final t in tools)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Icon(t.$1, color: AppColors.primary),
              title: Text(t.$2),
              subtitle: Text(t.$3),
              trailing: Icon(
                isPro
                    ? Icons.chevron_right_rounded
                    : Icons.lock_outline_rounded,
                color: AppColors.textMutedDark,
              ),
              onTap: () => isPro
                  ? context.push(t.$4)
                  : showProUpsell(context, feature: t.$2, description: t.$5),
            ),
        ],
      ),
    );
  }
}
