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
  bool _isEditing = false;
  String? _existingProposalId;
  Proposal? _existingProposal;
  bool _initializedFromExisting = false;

  List<ProposedMilestone> _milestones = [
    const ProposedMilestone(title: 'Estrutura base & Telas iniciais', amount: 1500, days: 7),
    const ProposedMilestone(title: 'Integrações, Testes e Entrega', amount: 1500, days: 8),
  ];

  @override
  void initState() {
    super.initState();
    _checkExistingProposal();
  }

  Future<void> _checkExistingProposal() async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    try {
      final repository = ref.read(proposalRepositoryProvider);
      final list = await repository.getFreelancerProposals(user.id);
      final match = list.where((p) => p.jobId == widget.jobId).toList();

      if (match.isNotEmpty && mounted && !_initializedFromExisting) {
        final prop = match.first;
        setState(() {
          _isEditing = true;
          _existingProposal = prop;
          _existingProposalId = prop.id;
          _bidController.text = prop.bidAmount.toStringAsFixed(2);
          _daysController.text = prop.estimatedDays.toString();
          _coverLetterController.text = prop.coverLetter;
          if (prop.proposedMilestones.isNotEmpty) {
            _milestones = List.from(prop.proposedMilestones);
          }
          _initializedFromExisting = true;
        });
      }
    } catch (_) {
      // Caso não consiga carregar previamente, segue com formulário padrão
    }
  }

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

  Future<void> _handleAcceptCounterOffer() async {
    if (_existingProposalId == null) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(proposalRepositoryProvider);
      await repo.acceptCounterOffer(_existingProposalId!);

      final user = ref.read(authProvider).value;
      if (user != null) {
        ref.invalidate(freelancerProposalsProvider(user.id));
      }
      ref.invalidate(jobProposalsProvider(widget.jobId));
      ref.invalidate(jobDetailProvider(widget.jobId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Contraproposta aceita! O contrato foi criado e o Escrow inicializado.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao aceitar contraproposta: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

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
        id: _existingProposalId ?? '',
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
      ref.invalidate(freelancerProposalsProvider(user.id));
      ref.invalidate(jobDetailProvider(widget.jobId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Proposta atualizada com sucesso!' : 'Proposta enviada com sucesso! O cliente foi notificado.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final errText = e.toString().contains('duplicate key')
            ? 'Você já enviou uma proposta para esta vaga. Os dados foram sincronizados.'
            : 'Falha ao processar proposta: ${e.toString().replaceAll("Exception: ", "")}';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errText),
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
        title: Text(_isEditing ? 'Editar Proposta' : 'Enviar Proposta'),
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
                // Banner de Contraproposta Recebida
                if (_existingProposal != null && _existingProposal!.hasActiveCounterOffer) ...[
                  GlassCard(
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
                                'O Cliente Enviou uma Contraproposta!',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.warning),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Novo Valor Ofertado: ${CurrencyFormatter.format(_existingProposal!.counterPrice!)}'
                          '${_existingProposal!.counterEstimatedDays != null ? " em ${_existingProposal!.counterEstimatedDays} dias" : ""}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
                        ),
                        if (_existingProposal!.counterMessage != null && _existingProposal!.counterMessage!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Mensagem do Cliente: "${_existingProposal!.counterMessage}"',
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textSecondaryDark),
                          ),
                        ],
                        const SizedBox(height: 14),
                        CustomButton(
                          text: 'Aceitar Contraproposta & Iniciar Contrato',
                          icon: Icons.check_circle_rounded,
                          isLoading: _isLoading,
                          width: double.infinity,
                          onPressed: _handleAcceptCounterOffer,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else if (_isEditing) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppColors.primaryLight, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Você já enviou uma proposta para esta vaga. Você pode atualizar os valores e condições abaixo.',
                            style: TextStyle(fontSize: 12, color: AppColors.textPrimaryDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                                const Text('Taxa de serviço Trabalhei (10%)', style: TextStyle(fontSize: 13, color: AppColors.textSecondaryDark)),
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
                  text: _isEditing ? 'Atualizar Minha Proposta' : 'Confirmar e Enviar Proposta',
                  icon: _isEditing ? Icons.save_rounded : Icons.send_rounded,
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
