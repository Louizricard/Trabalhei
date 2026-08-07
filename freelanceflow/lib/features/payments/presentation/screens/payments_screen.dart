import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../providers/payments_provider.dart';
import '../widgets/payment_method_selector_modal.dart';
import '../widgets/pix_withdraw_modal.dart';

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  void _showDepositDialog(BuildContext context, WidgetRef ref) {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderDark),
        ),
        title: const Row(
          children: [
            Icon(Icons.add_card_rounded, color: AppColors.primary, size: 24),
            SizedBox(width: 8),
            Text(
              'Adicionar Saldo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryDark,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informe o valor que deseja depositar em sua carteira para contratações:',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryDark,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                prefixText: 'R\$ ',
                prefixStyle: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                hintText: '100.00',
                filled: true,
                fillColor: AppColors.surfaceElevatedDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderDark),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderDark),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondaryDark),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              final val =
                  double.tryParse(amountController.text.replaceAll(',', '.')) ??
                  0.0;
              if (val <= 0) return;
              Navigator.pop(ctx);
              PaymentMethodSelectorModal.show(
                context,
                amount: val,
                title: 'Depósito na Carteira',
                onPaymentSuccess: () {
                  ref.invalidate(transactionsListProvider);
                  ref.invalidate(walletSummaryProvider);
                },
              );
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsListProvider);
    final summaryAsync = ref.watch(walletSummaryProvider);

    final availableBalance = summaryAsync.value?.availableBalance ?? 0.0;
    final escrowBalance = summaryAsync.value?.escrowBalance ?? 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Carteira & Escrow')),
      body: ResponsiveLayout(
        maxWidth: 800,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(transactionsListProvider);
            ref.invalidate(walletSummaryProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Saldo Disponível na Carteira',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                CurrencyFormatter.format(availableBalance),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              CustomButton(
                                text: 'Depositar',
                                icon: Icons.add_rounded,
                                onPressed: () =>
                                    _showDepositDialog(context, ref),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(
                                    color: AppColors.primary,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                ),
                                icon: const Icon(Icons.pix_rounded, size: 16),
                                label: const Text(
                                  'Sacar',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: AppColors.transparent,
                                    isScrollControlled: true,
                                    builder: (_) => PixWithdrawModal(
                                      availableBalance: availableBalance,
                                      onWithdrawSuccess: () {
                                        ref.invalidate(
                                          transactionsListProvider,
                                        );
                                        ref.invalidate(walletSummaryProvider);
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          const Icon(
                            Icons.shield_rounded,
                            size: 16,
                            color: AppColors.escrow,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Retido em Garantia (Escrow Ativo):',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            CurrencyFormatter.format(escrowBalance),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.escrow,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Histórico de Transações',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: 12),
                transactionsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => EmptyStateWidget(
                    icon: Icons.error_outline_rounded,
                    title: 'Erro ao carregar extrato',
                    description: err.toString(),
                  ),
                  data: (transactions) {
                    if (transactions.isEmpty) {
                      return const EmptyStateWidget(
                        icon: Icons.receipt_long_rounded,
                        title: 'Nenhuma transação recente',
                        description:
                            'Os pagamentos via Pix, depósitos e liberações de escrow aparecerão listados aqui.',
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: transactions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final tx = transactions[index];
                        return GlassCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: tx.isCredit
                                    ? AppColors.successBg
                                    : AppColors.surfaceElevatedDark,
                                child: Icon(
                                  tx.isCredit
                                      ? Icons.arrow_downward_rounded
                                      : Icons.arrow_upward_rounded,
                                  size: 18,
                                  color: tx.isCredit
                                      ? AppColors.success
                                      : AppColors.textSecondaryDark,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx.typeLabel,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppColors.textPrimaryDark,
                                      ),
                                    ),
                                    if (tx.contractTitle != null)
                                      Text(
                                        tx.contractTitle!,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondaryDark,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    Row(
                                      children: [
                                        Text(
                                          DateFormatter.simpleDate(
                                            tx.createdAt,
                                          ),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMutedDark,
                                          ),
                                        ),
                                        if (tx.gatewayProvider != null) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            '• ${tx.paymentMethod == "credit_card" ? "Cartão" : "Pix"} Mercado Pago',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${tx.isCredit ? '+ ' : '- '}${CurrencyFormatter.format(tx.amount)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: tx.isCredit
                                      ? AppColors.success
                                      : AppColors.textPrimaryDark,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
