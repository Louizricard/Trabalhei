import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freelanceflow/core/theme/app_colors.dart';
import 'package:freelanceflow/core/utils/currency_formatter.dart';
import 'package:freelanceflow/core/utils/date_formatter.dart';
import 'package:freelanceflow/core/widgets/custom_button.dart';
import 'package:freelanceflow/core/widgets/empty_state.dart';
import 'package:freelanceflow/core/widgets/glass_card.dart';
import 'package:freelanceflow/core/widgets/responsive_layout.dart';
import 'package:freelanceflow/core/widgets/status_badge.dart';
import 'package:freelanceflow/features/auth/domain/entities/user_profile.dart';
import 'package:freelanceflow/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:freelanceflow/features/jobs/domain/entities/job.dart';
import 'package:freelanceflow/features/jobs/presentation/providers/jobs_provider.dart';
import 'package:freelanceflow/features/proposals/domain/entities/proposal.dart';
import 'package:freelanceflow/features/proposals/presentation/providers/proposals_provider.dart';
import 'package:go_router/go_router.dart';

class JobDetailScreen extends ConsumerWidget {
  final String jobId;

  const JobDetailScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(jobDetailProvider(jobId));
    final currentUser = ref.watch(authProvider).value;
    final proposalsAsync = currentUser != null
        ? ref.watch(freelancerProposalsProvider(currentUser.id))
        : const AsyncValue<List<Proposal>>.data([]);
    final hasApplied = proposalsAsync.maybeWhen(
      data: (list) => list.any((p) => p.jobId == jobId),
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da Vaga'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: jobAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => EmptyStateWidget(
          icon: Icons.error_outline_rounded,
          title: 'Erro ao carregar detalhes',
          description: err.toString(),
        ),
        data: (job) {
          if (job == null) {
            return const EmptyStateWidget(
              icon: Icons.search_off_rounded,
              title: 'Vaga não encontrada',
              description: 'A vaga pode ter sido encerrada ou removida.',
            );
          }

          final isOwner = currentUser?.id == job.clientId || currentUser?.role == UserRole.client;

          return ResponsiveLayout(
            maxWidth: 800,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (job.isUrgent) ...[StatusBadge.urgent(), const SizedBox(width: 8)],
                      if (job.isFeatured) ...[StatusBadge.featured(), const SizedBox(width: 8)],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevatedDark,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(job.category, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark)),
                      ),
                      const Spacer(),
                      Text(DateFormatter.relativeTime(job.createdAt), style: const TextStyle(color: AppColors.textMutedDark, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(job.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark)),
                  const SizedBox(height: 20),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _DetailMetric(
                          icon: Icons.payments_outlined,
                          title: job.contractType == ContractType.fixed ? 'Orçamento Estimado' : 'Valor por Hora',
                          value: CurrencyFormatter.formatRange(job.budgetMin, job.budgetMax),
                          valueColor: AppColors.success,
                        ),
                        Container(height: 40, width: 1, color: AppColors.borderDark),
                        _DetailMetric(
                          icon: Icons.calendar_month_outlined,
                          title: 'Prazo Previsto',
                          value: '${job.deadlineDays} dias',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Descrição do Projeto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark)),
                  const SizedBox(height: 8),
                  Text(job.description, style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textSecondaryDark)),
                  const SizedBox(height: 24),
                  if (job.skillsRequired.isNotEmpty) ...[
                    const Text('Habilidades Necessárias', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: job.skillsRequired.map((skill) {
                        return Chip(
                          label: Text(skill),
                          backgroundColor: AppColors.primary.withAlpha(30),
                          labelStyle: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w600),
                          side: const BorderSide(color: AppColors.primaryDark),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            job.clientName.trim().isNotEmpty ? job.clientName.trim()[0].toUpperCase() : 'C',
                            style: const TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(job.clientName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark, fontSize: 14)),
                                const SizedBox(width: 6),
                                const Icon(Icons.verified, size: 16, color: AppColors.primaryLight),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, size: 16, color: AppColors.warning),
                                const SizedBox(width: 4),
                                Text('${job.clientRating.toStringAsFixed(1)} (12 contratações)', style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (isOwner) ...[
                    CustomButton(
                      text: 'Ver Propostas Recebidas (${job.proposalsCount})',
                      icon: Icons.list_alt_rounded,
                      width: double.infinity,
                      onPressed: () => context.push('/jobs/${job.id}/proposals'),
                    ),
                  ] else ...[
                    CustomButton(
                      text: hasApplied ? 'Editar Minha Proposta Enviada' : 'Enviar Proposta para esta Vaga',
                      icon: hasApplied ? Icons.edit_note_rounded : Icons.send_rounded,
                      width: double.infinity,
                      onPressed: () => context.push('/jobs/${job.id}/apply'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;

  const _DetailMetric({
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondaryDark),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textMutedDark)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor ?? AppColors.textPrimaryDark)),
      ],
    );
  }
}
