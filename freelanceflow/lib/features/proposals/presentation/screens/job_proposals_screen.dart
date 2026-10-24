import 'package:trabalhei/core/utils/rating_formatter.dart';
import '../../../../core/errors/backend_errors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../jobs/presentation/providers/jobs_provider.dart';
import '../../domain/entities/proposal.dart';
import '../providers/proposals_provider.dart';
import '../widgets/counter_offer_modal.dart';

class JobProposalsScreen extends ConsumerStatefulWidget {
  final String jobId;

  const JobProposalsScreen({super.key, required this.jobId});

  @override
  ConsumerState<JobProposalsScreen> createState() => _JobProposalsScreenState();
}

class _JobProposalsScreenState extends ConsumerState<JobProposalsScreen> {
  bool _isProcessing = false;

  Future<void> _handleAcceptProposal(
    Proposal proposal,
    String? clientId,
  ) async {
    setState(() => _isProcessing = true);
    try {
      final repository = ref.read(proposalRepositoryProvider);
      // Cria o contrato de forma atômica no servidor (sem custódia de valores).
      final contractResult = await repository.acceptProposal(proposal.id);
      final contractId = contractResult['contract_id'] as String?;

      final cId = clientId ?? ref.read(authProvider).value?.id;
      if (cId == null) throw Exception('Faça login para continuar.');

      final conv = await ref
          .read(chatRepositoryProvider)
          .getOrCreateConversation(
            jobId: widget.jobId,
            freelancerId: proposal.freelancerId,
            clientId: cId,
            contractId: contractId,
          );

      ref.invalidate(jobProposalsProvider(widget.jobId));
      ref.invalidate(jobDetailProvider(widget.jobId));
      ref.invalidate(jobsListProvider);
      ref.invalidate(conversationsListProvider);
      ref.invalidate(conversationDetailProvider(conv.id));
      ref.invalidate(clientStatsProvider);
      ref.invalidate(freelancerStatsProvider);

      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Proposta aceita! O contrato foi criado.'),
          backgroundColor: AppColors.success,
        ),
      );
      context.push('/chat/${conv.id}');
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro ao aceitar proposta: ${friendlyError(e)}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleStartChat(Proposal proposal, String? clientId) async {
    final cId = clientId ?? ref.read(authProvider).value?.id;
    if (cId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Faça login para iniciar o chat'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final conv = await chatRepo.getOrCreateConversation(
        jobId: widget.jobId,
        freelancerId: proposal.freelancerId,
        clientId: cId,
      );

      if (mounted) {
        context.push('/chat/${conv.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao iniciar chat: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleRejectProposal(Proposal proposal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          'Recusar Proposta',
          style: TextStyle(color: AppColors.textPrimaryDark),
        ),
        content: Text(
          'Deseja recusar a proposta de ${proposal.freelancerName}?',
          style: const TextStyle(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondaryDark),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.pureWhite,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Recusar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      final repository = ref.read(proposalRepositoryProvider);
      await repository.rejectProposal(proposal.id);

      if (mounted) {
        ref.invalidate(jobProposalsProvider(widget.jobId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proposta recusada.'),
            backgroundColor: AppColors.info,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao recusar proposta: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobAsync = ref.watch(jobDetailProvider(widget.jobId));
    final proposalsAsync = ref.watch(jobProposalsProvider(widget.jobId));
    final currentUserId = ref.watch(authProvider).value?.id;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimaryDark,
          ),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Propostas Recebidas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryDark,
              ),
            ),
            jobAsync.maybeWhen(
              data: (job) => job != null
                  ? Text(
                      job.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryDark,
                      ),
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.textSecondaryDark,
            ),
            onPressed: () => ref.invalidate(jobProposalsProvider(widget.jobId)),
            tooltip: 'Atualizar Propostas',
          ),
        ],
      ),
      body: proposalsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryLight),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Erro ao carregar propostas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Tentar Novamente',
                  icon: Icons.refresh_rounded,
                  onPressed: () =>
                      ref.invalidate(jobProposalsProvider(widget.jobId)),
                ),
              ],
            ),
          ),
        ),
        data: (proposals) {
          if (proposals.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevatedDark,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: const Icon(
                        Icons.inbox_rounded,
                        size: 56,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Nenhuma proposta recebida ainda',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Freelancers qualificados estão visualizando sua vaga. Assim que enviarem propostas, elas aparecerão aqui.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondaryDark,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final clientId = jobAsync.value?.clientId ?? currentUserId;

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(jobProposalsProvider(widget.jobId));
                  ref.invalidate(jobDetailProvider(widget.jobId));
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Métricas resumidas
                    _buildSummaryMetrics(proposals),
                    const SizedBox(height: 16),

                    // Lista de propostas
                    for (final proposal in proposals) ...[
                      _buildProposalCard(proposal, clientId),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              if (_isProcessing)
                Container(
                  color: AppColors.bgDark.withAlpha(180),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryMetrics(List<Proposal> proposals) {
    double minBid = double.infinity;
    double maxBid = 0;
    int totalDays = 0;

    for (final p in proposals) {
      if (p.bidAmount < minBid) minBid = p.bidAmount;
      if (p.bidAmount > maxBid) maxBid = p.bidAmount;
      totalDays += p.estimatedDays;
    }

    final avgDays = (totalDays / proposals.length).round();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricItem(
            'Total',
            '${proposals.length}',
            Icons.people_outline_rounded,
            AppColors.primaryLight,
          ),
          _buildMetricItem(
            'Menor Proposta',
            CurrencyFormatter.format(minBid),
            Icons.trending_down_rounded,
            AppColors.success,
          ),
          _buildMetricItem(
            'Maior Proposta',
            CurrencyFormatter.format(maxBid),
            Icons.trending_up_rounded,
            AppColors.info,
          ),
          _buildMetricItem(
            'Prazo Médio',
            '$avgDays dias',
            Icons.schedule_rounded,
            AppColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimaryDark,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondaryDark,
          ),
        ),
      ],
    );
  }

  Widget _buildProposalCard(Proposal proposal, String? clientId) {
    final isAccepted = proposal.status == ProposalStatus.accepted;
    final isRejected = proposal.status == ProposalStatus.rejected;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho com Freelancer e Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => context.push('/profile/${proposal.freelancerId}'),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryDark,
                  child: Text(
                    proposal.freelancerName.isNotEmpty
                        ? proposal.freelancerName[0].toUpperCase()
                        : 'F',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () =>
                      context.push('/profile/${proposal.freelancerId}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              proposal.freelancerName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimaryDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.open_in_new_rounded,
                            size: 14,
                            color: AppColors.primaryLight,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            RatingFormatter.format(proposal.freelancerRating),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${proposal.estimatedDays} dias de prazo',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              _buildStatusBadge(proposal.status),
            ],
          ),
          const SizedBox(height: 14),

          // Valor proposto em destaque
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevatedDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Valor Ofertado:',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                Text(
                  CurrencyFormatter.format(proposal.bidAmount),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Carta de Apresentação / Mensagem
          const Text(
            'Carta de Apresentação:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.borderDark.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              proposal.coverLetter.isNotEmpty
                  ? proposal.coverLetter
                  : 'Nenhuma mensagem adicional informada.',
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textPrimaryDark,
              ),
            ),
          ),

          // Marcos Propostos (se houver)
          if (proposal.proposedMilestones.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Marcos Propostos (${proposal.proposedMilestones.length}):',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryDark,
              ),
            ),
            const SizedBox(height: 6),
            Column(
              children: [
                for (int i = 0; i < proposal.proposedMilestones.length; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevatedDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.primaryLight.withValues(
                            alpha: 0.2,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryLight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            proposal.proposedMilestones[i].title,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimaryDark,
                            ),
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(
                            proposal.proposedMilestones[i].amount,
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],

          // Banner de Contraproposta Ativa
          if (proposal.status == ProposalStatus.counterOffered &&
              proposal.counterPrice != null) ...[
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(12),
              backgroundColor: AppColors.info.withAlpha(20),
              borderColor: AppColors.info.withAlpha(60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.handshake_rounded,
                        size: 16,
                        color: AppColors.info,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Contraproposta Enviada ao Freelancer',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.info,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        CurrencyFormatter.format(proposal.counterPrice!),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.info,
                        ),
                      ),
                    ],
                  ),
                  if (proposal.counterEstimatedDays != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Prazo proposto: ${proposal.counterEstimatedDays} dias',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                  if (proposal.counterMessage != null &&
                      proposal.counterMessage!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Mensagem: "${proposal.counterMessage}"',
                      style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Botões de Ação
          if (!isAccepted && !isRejected) ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.pureWhite,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18,
                    ),
                    label: Text(
                      proposal.status == ProposalStatus.counterOffered
                          ? 'Contratar'
                          : 'Aceitar & Contratar',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    onPressed: () => _handleAcceptProposal(proposal, clientId),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: const BorderSide(color: AppColors.warning),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.handshake_outlined, size: 16),
                    label: const Text(
                      'Negociar',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: AppColors.transparent,
                        isScrollControlled: true,
                        builder: (_) => CounterOfferModal(proposal: proposal),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryLight,
                      side: const BorderSide(color: AppColors.primaryLight),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.chat_outlined, size: 16),
                    label: const Text(
                      'Chat',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    onPressed: () => _handleStartChat(proposal, clientId),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondaryDark,
                    size: 20,
                  ),
                  tooltip: 'Recusar Proposta',
                  onPressed: () => _handleRejectProposal(proposal),
                ),
              ],
            ),
          ] else if (isAccepted) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryLight,
                      side: const BorderSide(color: AppColors.primaryLight),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 18,
                    ),
                    label: const Text(
                      'Abrir Chat do Contrato',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _handleStartChat(proposal, clientId),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ProposalStatus status) {
    Color bg;
    Color fg;
    String text;

    switch (status) {
      case ProposalStatus.accepted:
        bg = AppColors.success.withValues(alpha: 0.15);
        fg = AppColors.success;
        text = 'Aceita';
        break;
      case ProposalStatus.rejected:
        bg = AppColors.error.withValues(alpha: 0.15);
        fg = AppColors.error;
        text = 'Recusada';
        break;
      case ProposalStatus.counterOffered:
        bg = AppColors.info.withValues(alpha: 0.15);
        fg = AppColors.info;
        text = 'Contraproposta';
        break;
      case ProposalStatus.pending:
        bg = AppColors.warning.withValues(alpha: 0.15);
        fg = AppColors.warning;
        text = 'Pendente';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
