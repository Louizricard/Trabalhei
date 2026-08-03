import '../entities/transaction.dart';

abstract class PaymentRepository {
  Future<List<WalletTransaction>> getTransactions();
  Future<void> requestPixWithdrawal({required double amount, required String pixKey});
  Future<void> depositEscrow({required double amount, required String contractId});
}
