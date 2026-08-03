import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../jobs/presentation/providers/jobs_provider.dart';
import '../../domain/entities/proposal.dart';
import '../providers/proposals_provider.dart';

class ApplyJobScreen extends ConsumerStatefulWidget {
  final String jobId;

  const ApplyJobScreen({super.key, required this.jobId});

  @override
  ConsumerState<ApplyJobScreen> createState() => _ApplyJobScreenState();
}

class _ApplyJobScreenState extends ConsumerState<ApplyJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bidController = TextEditingController(text: '3000');
  final _daysController = TextEditingController(text: '15');
  final _coverLetterController = TextEditingController();
  bool _isLoading = false;

  final List<ProposedMilestone> _milestones = [
    const ProposedMilestone(title: 'Estrutura base & Telas iniciais', amount: 1500, days: 7),
    const ProposedMilestone(title: 'Integrações, Testes e Entrega', amount: 1500, days: 8),
  ];

  @override
  void dispose() {
    _bidController.dispose();
    _daysController.dispose();
    _coverLetterController.dispose();
    super.dispose();
  }

  double get _bidAmount => double.tryParse(_bidController.text) ?? 0.0;
  double get _platformFee => _bidAmount * 0.10;
  double get _netEarnings => _bidAmount - _platformFee;

  Future<void> _submitProposal() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = ref.read(authProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você precisa estar logado para enviar propostas.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final proposal = Proposal(
        id: '',
        jobId: widget.jobId,
        freelancerId: user.id,
        freelancerName: user.fullName,
        freelancerRating: user.rating,
        bidAmount: _bidAmount,
        estimatedDays: int.tryParse(_daysController.text) ?? 14,
        coverLetter: _coverLetterController.text.trim(),
        proposedMilestones: _milestones,
        createdAt: DateTime.now(),
      );

      await ref.read(proposalRepositoryProvider).submitProposal(proposal);
      ref.invalidate(jobProposalsProvider(widget.jobId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proposta enviada com sucesso! O cliente foi notificado.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao enviar proposta: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(jobDetailProvider(widget.jobId)).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enviar Proposta'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
      ),
      body: ResponsiveLayout(
        maxWidth: 700,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (job != null) ...[
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Candidatando-se para:', style: TextStyle(fontSize: 12, color: AppColors.textMutedDark)),
                        const SizedBox(height: 4),
                        Text(job.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimaryDark)),
                        const SizedBox(height: 6),
                        Text(
                          'Orçamento sugerido pelo cliente: ${CurrencyFormatter.formatRange(job.budgetMin, job.budgetMax)}',
                          style: const TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Termos da Proposta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _bidController,
                              label: 'Valor Total da Proposta (R\$)',
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              validator: (v) => v != null && (double.tryParse(v) ?? 0) > 0 ? null : 'Valor inválido',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomTextField(
                              controller: _daysController,
                              label: 'Prazo Estimado (Dias)',
                              keyboardType: TextInputType.number,
                              validator: (v) => v != null && (int.tryParse(v) ?? 0) > 0 ? null : 'Prazo inválido',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevatedDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Taxa de serviço FreelanceFlow (10%)', style: TextStyle(fontSize: 13, color: AppColors.textSecondaryDark)),
                                Text('- ${CurrencyFormatter.format(_platformFee)}', style: const TextStyle(fontSize: 13, color: AppColors.error)),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Você receberá (Líquido em Escrow)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark)),
                                Text(CurrencyFormatter.format(_netEarnings), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.success)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Carta de Apresentação', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _coverLetterController,
                        label: 'Por que você é a pessoa ideal para este projeto?',
                        hint: 'Apresente suas experiências relevantes, abordagem técnica e links para projetos similares...',
                        maxLines: 6,
                        validator: (v) => v != null && v.length >= 30 ? null : 'Mínimo de 30 caracteres para uma proposta competitiva',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                CustomButton(
                  text: 'Confirmar e Enviar Proposta',
                  icon: Icons.send_rounded,
                  isLoading: _isLoading,
                  width: double.infinity,
                  onPressed: _submitProposal,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
