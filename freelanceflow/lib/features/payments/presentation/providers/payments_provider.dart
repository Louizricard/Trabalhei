import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_client.dart';
import '../../data/datasources/payment_remote_data_source.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/payment_repository.dart';

final paymentDataSourceProvider = Provider<PaymentRemoteDataSource>((ref) {
  return PaymentRemoteDataSource(ref.watch(supabaseClientProvider));
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepositoryImpl(ref.watch(paymentDataSourceProvider));
});

final transactionsListProvider = FutureProvider<List<WalletTransaction>>((ref) async {
  final repository = ref.watch(paymentRepositoryProvider);
  return repository.getTransactions();
});

class WalletSummary {
  final double availableBalance;
  final double escrowBalance;

  const WalletSummary({
    required this.availableBalance,
    required this.escrowBalance,
  });
}

final walletSummaryProvider = FutureProvider<WalletSummary>((ref) async {
  final transactions = await ref.watch(transactionsListProvider.future);
  final supabase = ref.watch(supabaseClientProvider);
  final user = supabase.auth.currentUser;

  double balance = 0.0;
  for (final tx in transactions) {
    if (tx.status == TransactionStatus.completed) {
      if (tx.isCredit) {
        balance += tx.amount;
      } else {
        balance -= tx.amount;
      }
    }
  }

  double escrow = 0.0;
  if (user != null) {
    try {
      final contracts = await supabase
          .from('contracts')
          .select('escrow_amount')
          .or('client_id.eq.${user.id},freelancer_id.eq.${user.id}')
          .eq('status', 'active');

      for (final c in (contracts as List<dynamic>)) {
        escrow += (c['escrow_amount'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (_) {}
  }

  return WalletSummary(
    availableBalance: balance < 0 ? 0.0 : balance,
    escrowBalance: escrow,
  );
});
