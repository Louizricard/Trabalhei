import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trabalhei/core/errors/backend_errors.dart';
import 'package:trabalhei/core/theme/app_colors.dart';
import 'package:trabalhei/core/utils/currency_formatter.dart';
import 'package:trabalhei/core/utils/date_formatter.dart';
import 'package:trabalhei/core/widgets/attachment_widgets.dart';
import 'package:trabalhei/core/widgets/custom_button.dart';
import 'package:trabalhei/core/widgets/empty_state.dart';
import 'package:trabalhei/core/widgets/glass_card.dart';
import 'package:trabalhei/core/widgets/responsive_layout.dart';
import 'package:trabalhei/core/widgets/status_badge.dart';
import 'package:trabalhei/features/auth/domain/entities/user_profile.dart';
import 'package:trabalhei/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:trabalhei/features/billing/presentation/widgets/feature_job_action.dart';
import 'package:trabalhei/features/jobs/domain/entities/job.dart';
import 'package:trabalhei/features/jobs/presentation/providers/jobs_provider.dart';
import 'package:trabalhei/features/proposals/domain/entities/proposal.dart';
import 'package:trabalhei/features/proposals/presentation/providers/proposals_provider.dart';
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
          description: friendlyError(err),
        ),
        data: (job) {
          if (job == null) {
            return const EmptyStateWidget(
              icon: Icons.search_off_rounded,
              title: 'Vaga não encontrada',
              description: 'A vaga pode ter sido encerrada ou removida.',
            );
          }
          final isOwner = currentUser != null && currentUser.id == job.clientId;
          final isOtherClient =
              currentUser?.role == UserRole.client && !isOwner;

          return ResponsiveLayout(
            maxWidth: 800,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevatedDark,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          job.category,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                      ),
                      const Spacer(),
                      _buildStatusBadge(job.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    job.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Publicado em ${DateFormatter.relativeTime(job.createdAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMutedDark,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _DetailMetric(
                          icon: Icons.payments_outlined,
                          title: 'Orçamento',
                          value: _formatBudget(job),
                          valueColor: AppColors.success,
                        ),
                        _DetailMetric(
                          icon: Icons.access_time_rounded,
                          title: 'Prazo Limite',
                          value: '${job.deadlineDays} dias',
                        ),
                        _DetailMetric(
                          icon: Icons.trending_up_rounded,
                          title: 'Nível',
                          value: _formatExpLevel(job.experienceLevel),
                        ),
                        _DetailMetric(
                          icon: Icons.assignment_outlined,
                          title: 'Propostas',
                          value: '${job.proposalsCount}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Descrição do Projeto',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    job.description,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                  if (job.attachments.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    AttachmentCardsList(
                      attachments: job.attachments,
                      title: 'Arquivos Anexados pelo Contratante',
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'Habilidades Necessárias',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: job.skillsRequired.map((skill) {
                      return Chip(
                        label: Text(skill),
                        backgroundColor: AppColors.surfaceElevatedDark,
                        labelStyle: const TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Sobre o Contratante',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            job.clientName.trim().isNotEmpty
                                ? job.clientName.trim()[0].toUpperCase()
                                : 'C',
                            style: const TextStyle(
                              color: AppColors.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  job.clientName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimaryDark,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: AppColors.warning,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  job.clientRating > 0
                                      ? job.clientRating.toStringAsFixed(1)
                                      : 'Sem avaliações ainda',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondaryDark,
                                  ),
                                ),
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
                      onPressed: () =>
                          context.push('/jobs/${job.id}/proposals'),
                    ),
                    const SizedBox(height: 12),
                    if (job.status == JobStatus.open) ...[
                      CustomButton(
                        text: job.isFeatured
                            ? 'Vaga em destaque até ${DateFormatter.simpleDate(job.featuredUntil!)}'
                            : 'Destacar Vaga por 7 dias',
                        icon: Icons.star_rounded,
                        variant: ButtonVariant.secondary,
                        width: double.infinity,
                        onPressed: job.isFeatured
                            ? null
                            : () => startFeatureJobFlow(context, ref, job),
                      ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: 'Editar Vaga',
                        icon: Icons.edit_rounded,
                        variant: ButtonVariant.outline,
                        width: double.infinity,
                        onPressed: () =>
                            context.push('/jobs/${job.id}/edit', extra: job),
                      ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: 'Cancelar Vaga',
                        icon: Icons.cancel_outlined,
                        variant: ButtonVariant.danger,
                        width: double.infinity,
                        onPressed: () => _confirmCancel(context, ref, job),
                      ),
                    ],
                  ] else if (isOtherClient) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevatedDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.textMutedDark,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Vaga publicada por outro contratante',
                            style: TextStyle(
                              color: AppColors.textSecondaryDark,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    CustomButton(
                      text: hasApplied
                          ? 'Editar Minha Proposta Enviada'
                          : 'Enviar Proposta para esta Vaga',
                      icon: hasApplied
                          ? Icons.edit_note_rounded
                          : Icons.send_rounded,
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

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    Job job,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar vaga?'),
        content: const Text(
          'A vaga sai do mural e as propostas pendentes serão recusadas. '
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancelar vaga'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(jobRepositoryProvider).cancelJob(job.id);
      ref.invalidate(jobDetailProvider(job.id));
      ref.invalidate(jobsListProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Vaga cancelada.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(friendlyError(e)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildStatusBadge(JobStatus status) {
    switch (status) {
      case JobStatus.inProgress:
        return StatusBadge.inProgress();
      case JobStatus.completed:
        return StatusBadge.completed();
      case JobStatus.cancelled:
        return const StatusBadge(
          label: 'Cancelada',
          backgroundColor: AppColors.errorBg,
          textColor: AppColors.error,
        );
      case JobStatus.open:
        return StatusBadge.open();
    }
  }

  String _formatExpLevel(ExperienceLevel level) {
    switch (level) {
      case ExperienceLevel.junior:
        return 'Iniciante / Júnior';
      case ExperienceLevel.pleno:
        return 'Intermediário / Pleno';
      case ExperienceLevel.senior:
        return 'Especialista / Sênior';
      case ExperienceLevel.all:
        return 'Todos os níveis';
    }
  }

  String _formatBudget(Job job) {
    if (job.budgetMin > 0 && job.budgetMax > 0) {
      return '${CurrencyFormatter.format(job.budgetMin)} - ${CurrencyFormatter.format(job.budgetMax)}';
    } else if (job.budgetMax > 0) {
      return 'Até ${CurrencyFormatter.format(job.budgetMax)}';
    } else if (job.budgetMin > 0) {
      return 'A partir de ${CurrencyFormatter.format(job.budgetMin)}';
    }
    return 'A combinar';
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
        Text(
          title,
          style: const TextStyle(fontSize: 11, color: AppColors.textMutedDark),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor ?? AppColors.textPrimaryDark,
          ),
        ),
      ],
    );
  }
}
