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
import '../widgets/pix_withdraw_modal.dart';

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsListProvider);
    final summaryAsync = ref.watch(walletSummaryProvider);

    final availableBalance = summaryAsync.value?.availableBalance ?? 0.0;
    final escrowBalance = summaryAsync.value?.escrowBalance ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carteira & Escrow'),
      ),
      body: ResponsiveLayout(
        maxWidth: 800,
        child: SingleChildScrollView(
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
                            const Text('Saldo Disponível para Saque', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark)),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.format(availableBalance),
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.success),
                            ),
                          ],
                        ),
                        CustomButton(
                          text: 'Sacar Pix',
                          icon: Icons.pix_rounded,
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: AppColors.transparent,
                              isScrollControlled: true,
                              builder: (_) => PixWithdrawModal(
                                availableBalance: availableBalance,
                                onWithdrawSuccess: () {
                                  ref.invalidate(transactionsListProvider);
                                  ref.invalidate(walletSummaryProvider);
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, size: 16, color: AppColors.info),
                        const SizedBox(width: 8),
                        const Text('Retido em Garantia (Escrow Ativo):', style: TextStyle(fontSize: 13, color: AppColors.textSecondaryDark)),
                        const Spacer(),
                        Text(
                          CurrencyFormatter.format(escrowBalance),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.info),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Histórico de Transações',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
              ),
              const SizedBox(height: 12),
              transactionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
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
                      description: 'Os pagamentos liberados e saques aparecerão listados aqui.',
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: tx.isCredit ? AppColors.successBg : AppColors.surfaceElevatedDark,
                              child: Icon(
                                tx.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                size: 18,
                                color: tx.isCredit ? AppColors.success : AppColors.textSecondaryDark,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                 Text(
                                    tx.typeLabel,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimaryDark),
                                  ),
                                  if (tx.contractTitle != null)
                                    Text(
                                      tx.contractTitle!,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryDark),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  Text(
                                    DateFormatter.simpleDate(tx.createdAt),
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMutedDark),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${tx.isCredit ? '+ ' : '- '}${CurrencyFormatter.format(tx.amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: tx.isCredit ? AppColors.success : AppColors.textPrimaryDark,
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
    );
  }
}
