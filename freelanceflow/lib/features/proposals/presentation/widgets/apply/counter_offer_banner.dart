import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/errors/backend_errors.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/widgets/custom_button.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../../chat/presentation/providers/chat_provider.dart';
import '../../../../jobs/presentation/providers/jobs_provider.dart';
import '../../../domain/entities/proposal.dart';
import '../../providers/proposals_provider.dart';

/// Contraproposta do cliente aguardando a resposta do freelancer. Aceitar
/// cria o contrato e abre a conversa; recusar devolve a proposta à análise
/// e avisa por [onRejected].
class CounterOfferBanner extends ConsumerStatefulWidget {
  final Proposal proposal;
  final ValueChanged<Proposal> onRejected;

  const CounterOfferBanner({
    super.key,
    required this.proposal,
    required this.onRejected,
  });

  @override
  ConsumerState<CounterOfferBanner> createState() => _CounterOfferBannerState();
}

class _CounterOfferBannerState extends ConsumerState<CounterOfferBanner> {
  bool _isLoading = false;

  void _refresh() {
    final user = ref.read(authProvider).value;
    if (user != null) ref.invalidate(freelancerProposalsProvider(user.id));
    ref.invalidate(jobProposalsProvider(widget.proposal.jobId));
    ref.invalidate(jobDetailProvider(widget.proposal.jobId));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _isLoading = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyError(e)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _accept() => _run(() async {
    final result = await ref
        .read(proposalRepositoryProvider)
        .acceptCounterOffer(widget.proposal.id);
    _refresh();
    ref.invalidate(conversationsListProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contraproposta aceita! O contrato foi criado.'),
        backgroundColor: AppColors.success,
      ),
    );
    final conversationId = result['conversation_id'] as String?;
    conversationId != null
        ? context.pushReplacement('/chat/$conversationId')
        : context.go('/jobs/${widget.proposal.jobId}');
  });

  Future<void> _reject() => _run(() async {
    await ref
        .read(proposalRepositoryProvider)
        .rejectCounterOffer(widget.proposal.id);
    _refresh();
    if (!mounted) return;
    widget.onRejected(
      widget.proposal.copyWith(
        status: ProposalStatus.pending,
        clearCounterOffer: true,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Contraproposta recusada. Sua proposta segue em análise.',
        ),
      ),
    );
  });

  @override
  Widget build(BuildContext context) {
    final proposal = widget.proposal;
    final days = proposal.counterEstimatedDays;
    final message = proposal.counterMessage;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: AppColors.warning.withAlpha(25),
      borderColor: AppColors.warning.withAlpha(80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.handshake_rounded, color: AppColors.warning, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'O cliente enviou uma contraproposta',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Novo valor ofertado: '
            '${CurrencyFormatter.format(proposal.counterPrice!)}'
            '${days != null ? ' em $days dias' : ''}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryDark,
            ),
          ),
          if (message != null && message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Mensagem do cliente: "$message"',
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondaryDark,
              ),
            ),
          ],
          const SizedBox(height: 14),
          CustomButton(
            text: 'Aceitar contraproposta e iniciar contrato',
            icon: Icons.check_circle_rounded,
            isLoading: _isLoading,
            width: double.infinity,
            onPressed: _accept,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isLoading ? null : _reject,
              child: const Text('Recusar contraproposta'),
            ),
          ),
        ],
      ),
    );
  }
}
