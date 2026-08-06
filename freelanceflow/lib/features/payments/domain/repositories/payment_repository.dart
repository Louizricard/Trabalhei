import '../entities/payment_intent.dart';
import '../entities/transaction.dart';

abstract class PaymentRepository {
  Future<List<WalletTransaction>> getTransactions();
  Future<void> requestPixWithdrawal({required double amount, required String pixKey});
  Future<void> depositEscrow({required double amount, required String contractId});
  
  Future<PaymentIntentResult> createPixPayment({
    String? contractId,
    required double amount,
    String? description,
    String? payerCpf,
    String? payerName,
  });

  Future<PaymentIntentResult> createCreditCardPayment({
    String? contractId,
    required double amount,
    required CardPaymentData cardData,
    String? description,
  });

  Future<PaymentIntentResult> checkPaymentStatus({
    String? gatewayRef,
    String? transactionId,
  });

  Stream<WalletTransaction?> listenToTransaction(String transactionId);
}
