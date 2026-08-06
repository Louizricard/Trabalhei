import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/custom_button.dart';
import '../providers/payments_provider.dart';
import 'credit_card_checkout_modal.dart';
import 'pix_escrow_modal.dart';

class PaymentMethodSelectorModal extends ConsumerStatefulWidget {
  final double amount;
  final String title;
  final String? contractId;
  final VoidCallback onPaymentSuccess;

  const PaymentMethodSelectorModal({
    super.key,
    required this.amount,
    required this.title,
    this.contractId,
    required this.onPaymentSuccess,
  });

  static Future<bool?> show(
    BuildContext context, {
    required double amount,
    required String title,
    String? contractId,
    required VoidCallback onPaymentSuccess,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentMethodSelectorModal(
        amount: amount,
        title: title,
        contractId: contractId,
        onPaymentSuccess: onPaymentSuccess,
      ),
    );
  }

  @override
  ConsumerState<PaymentMethodSelectorModal> createState() => _PaymentMethodSelectorModalState();
}

class _PaymentMethodSelectorModalState extends ConsumerState<PaymentMethodSelectorModal> {
  String _selectedMethod = 'pix'; // 'pix', 'credit_card', 'wallet'
  bool _isLoading = false;

  Future<void> _handleProceed() async {
    if (_selectedMethod == 'pix') {
      setState(() => _isLoading = true);
      try {
        final repository = ref.read(paymentRepositoryProvider);
        final result = await repository.createPixPayment(
          contractId: widget.contractId,
          amount: widget.amount,
          description: 'Garantia de Escrow Trabalhei - ${widget.title}',
        );

        if (!mounted) return;
        setState(() => _isLoading = false);

        if (result.success && result.qrCode != null) {
          Navigator.of(context).pop(); // Fecha seletor
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => PixEscrowModal(
              paymentIntent: result,
              amount: widget.amount,
              title: widget.title,
              onPaymentConfirmed: widget.onPaymentSuccess,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Não foi possível gerar a chave Pix. Tente novamente.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro: ${e.toString().replaceAll("Exception: ", "")}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } else if (_selectedMethod == 'credit_card') {
      Navigator.of(context).pop(); // Fecha seletor
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => CreditCardCheckoutModal(
          amount: widget.amount,
          title: widget.title,
          contractId: widget.contractId,
          onPaymentConfirmed: widget.onPaymentSuccess,
        ),
      );
    } else if (_selectedMethod == 'wallet') {
      setState(() => _isLoading = true);
      try {
        if (widget.contractId != null) {
          await ref.read(paymentRepositoryProvider).depositEscrow(
            amount: widget.amount,
            contractId: widget.contractId!,
          );
        }
        ref.invalidate(walletSummaryProvider);
        ref.invalidate(transactionsListProvider);
        widget.onPaymentSuccess();

        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Pagamento realizado com sucesso utilizando o saldo da carteira!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro no pagamento com saldo: ${e.toString().replaceAll("Exception: ", "")}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletSummary = ref.watch(walletSummaryProvider).value;
    final availableBalance = walletSummary?.availableBalance ?? 0.0;
    final hasEnoughBalance = availableBalance >= widget.amount;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Escolha a forma de pagamento',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryDark,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textMutedDark),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Card Resumo do Valor
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryDark,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Total a garantir em Custódia (Escrow)',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.escrow,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.format(widget.amount),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Opção: PIX
          _PaymentOptionTile(
            id: 'pix',
            selectedId: _selectedMethod,
            icon: Icons.qr_code_2_rounded,
            title: 'Pix Instantâneo (Mercado Pago)',
            subtitle: 'Aprovação imediata com QR Code ou Copia e Cola',
            badge: 'MAIS RÁPIDO',
            onTap: () => setState(() => _selectedMethod = 'pix'),
          ),
          const SizedBox(height: 10),

          // Opção: Cartão de Crédito
          _PaymentOptionTile(
            id: 'credit_card',
            selectedId: _selectedMethod,
            icon: Icons.credit_card_rounded,
            title: 'Cartão de Crédito (Mercado Pago)',
            subtitle: 'Em até 12x sem juros no checkout transparente',
            onTap: () => setState(() => _selectedMethod = 'credit_card'),
          ),
          const SizedBox(height: 10),

          // Opção: Saldo da Carteira (se disponível)
          if (availableBalance > 0) ...[
            _PaymentOptionTile(
              id: 'wallet',
              selectedId: _selectedMethod,
              icon: Icons.account_balance_wallet_rounded,
              title: 'Saldo da Carteira Trabalhei',
              subtitle: 'Saldo disponível: ${CurrencyFormatter.format(availableBalance)}',
              badge: hasEnoughBalance ? 'DISPONÍVEL' : 'INSUFICIENTE',
              badgeColor: hasEnoughBalance ? AppColors.success : AppColors.error,
              enabled: hasEnoughBalance,
              onTap: hasEnoughBalance ? () => setState(() => _selectedMethod = 'wallet') : null,
            ),
            const SizedBox(height: 10),
          ],

          const SizedBox(height: 12),

          // Botão Continuar
          CustomButton(
            text: _selectedMethod == 'pix'
                ? 'Gerar QR Code Pix'
                : (_selectedMethod == 'credit_card' ? 'Preencher Dados do Cartão' : 'Pagar com Saldo'),
            icon: Icons.arrow_forward_rounded,
            isLoading: _isLoading,
            onPressed: _handleProceed,
          ),
        ],
      ),
    );
  }
}

class _PaymentOptionTile extends StatelessWidget {
  final String id;
  final String selectedId;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final Color? badgeColor;
  final bool enabled;
  final VoidCallback? onTap;

  const _PaymentOptionTile({
    required this.id,
    required this.selectedId,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    this.badgeColor,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = id == selectedId && enabled;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer : AppColors.cardDark.withValues(alpha: enabled ? 1.0 : 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderDark,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surfaceElevatedDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.onPrimary : (enabled ? AppColors.primary : AppColors.textDisabledDark),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: enabled ? AppColors.textPrimaryDark : AppColors.textDisabledDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? AppColors.primary).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge!,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: badgeColor ?? AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: enabled ? AppColors.textSecondaryDark : AppColors.textDisabledDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.primary : AppColors.textMutedDark,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
