import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/entities/proposal.dart';
import '../providers/proposals_provider.dart';

class CounterOfferModal extends ConsumerStatefulWidget {
  final Proposal proposal;

  const CounterOfferModal({super.key, required this.proposal});

  @override
  ConsumerState<CounterOfferModal> createState() => _CounterOfferModalState();
}

class _CounterOfferModalState extends ConsumerState<CounterOfferModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _priceController;
  late final TextEditingController _daysController;
  final _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(text: widget.proposal.bidAmount.toStringAsFixed(0));
    _daysController = TextEditingController(text: widget.proposal.estimatedDays.toString());
  }

  @override
  void dispose() {
    _priceController.dispose();
    _daysController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitCounterOffer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final price = double.tryParse(_priceController.text);
    final days = int.tryParse(_daysController.text);

    if (price == null || price <= 0 || days == null || days <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, informe valores válidos.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(proposalRepositoryProvider).makeCounterOffer(
            proposalId: widget.proposal.id,
            counterPrice: price,
            counterEstimatedDays: days,
            counterMessage: _messageController.text.trim().isNotEmpty ? _messageController.text.trim() : null,
          );

      ref.invalidate(jobProposalsProvider(widget.proposal.jobId));
      ref.invalidate(freelancerProposalsProvider(widget.proposal.freelancerId));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Contraproposta de ${CurrencyFormatter.format(price)} enviada com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar contraproposta: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.handshake_outlined, color: AppColors.primaryLight),
                      SizedBox(width: 8),
                      Text(
                        'Negociar / Fazer Contraproposta',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Negocie valores ou prazos diretamente com ${widget.proposal.freelancerName}.',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryDark),
              ),
              const SizedBox(height: 14),
              GlassCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Valor Original', style: TextStyle(fontSize: 11, color: AppColors.textMutedDark)),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.format(widget.proposal.bidAmount),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimaryDark),
                        ),
                      ],
                    ),
                    Container(height: 30, width: 1, color: AppColors.borderDark),
                    Column(
                      children: [
                        const Text('Prazo Original', style: TextStyle(fontSize: 11, color: AppColors.textMutedDark)),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.proposal.estimatedDays} dias',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimaryDark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _priceController,
                      label: 'Novo Valor Ofertado (R\$)',
                      keyboardType: TextInputType.number,
                      validator: (v) => (v == null || v.isEmpty) ? 'Informe o valor' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _daysController,
                      label: 'Novo Prazo (Dias)',
                      keyboardType: TextInputType.number,
                      validator: (v) => (v == null || v.isEmpty) ? 'Informe os dias' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              CustomTextField(
                controller: _messageController,
                label: 'Mensagem / Justificativa (Opcional)',
                hint: 'Ex: Conseguimos fechar por este valor se entregarmos até o dia X...',
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              CustomButton(
                text: 'Enviar Contraproposta',
                icon: Icons.send_rounded,
                isLoading: _isLoading,
                width: double.infinity,
                onPressed: _submitCounterOffer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
