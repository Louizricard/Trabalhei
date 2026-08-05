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
import 'package:go_router/go_router.dart';

class ClientDashboardScreen extends ConsumerWidget {
  const ClientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(clientStatsProvider);
    final user = ref.watch(authProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard do Contratante'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Publicar Projeto',
            onPressed: () => context.push('/jobs/create'),
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
                            (user?.fullName.trim().isNotEmpty ?? false)
                                ? user!.fullName.trim()[0].toUpperCase()
                                : 'C',
                            style: const TextStyle(fontSize: 18, color: AppColors.onPrimary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.companyName ?? user?.fullName ?? 'TechSolutions',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Empresa Verificada • 12 Projetos Concluídos',
                                style: TextStyle(fontSize: 12, color: AppColors.primaryLight, fontWeight: FontWeight.w600),
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
                              const Text('Garantido em Escrow', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark)),
                              const SizedBox(height: 6),
                              Text(
                                CurrencyFormatter.format(stats.activeEscrowBalance),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.info),
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
                              const Text('Total Investido', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark)),
                              const SizedBox(height: 6),
                              Text(
                                CurrencyFormatter.format(stats.totalSpent),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.success),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: 'Publicar Nova Vaga no Mural',
                    icon: Icons.add_circle_outline,
                    width: double.infinity,
                    onPressed: () => context.push('/jobs/create'),
                  ),
                  const SizedBox(height: 20),
                  GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Gestão de Talentos e Vagas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 14),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.surfaceElevatedDark,
                            child: Icon(Icons.work_outline, color: AppColors.primaryLight),
                          ),
                          title: Text('${stats.activeJobsCount} Vagas Abertas no Mural', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Recebendo candidaturas e propostas', style: TextStyle(fontSize: 12, color: AppColors.textMutedDark)),
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondaryDark),
                          onTap: () => context.push('/jobs'),
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.surfaceElevatedDark,
                            child: Icon(Icons.handshake_outlined, color: AppColors.success),
                          ),
                          title: Text('${stats.activeContractsCount} Contratos em Andamento', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Acompanhe entregas e liberação de marcos', style: TextStyle(fontSize: 12, color: AppColors.textMutedDark)),
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondaryDark),
                          onTap: () => context.push('/chat'),
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
