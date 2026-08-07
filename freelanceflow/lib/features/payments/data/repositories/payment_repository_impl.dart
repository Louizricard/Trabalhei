import '../../domain/entities/payment_intent.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/payment_repository.dart';
import '../datasources/payment_remote_data_source.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentRemoteDataSource _remoteDataSource;

  PaymentRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<WalletTransaction>> getTransactions() {
    return _remoteDataSource.getTransactions();
  }

  @override
  Future<void> requestPixWithdrawal({
    required double amount,
    required String pixKey,
  }) {
    return _remoteDataSource.requestPixWithdrawal(
      amount: amount,
      pixKey: pixKey,
    );
  }

  @override
  Future<void> depositEscrow({
    required double amount,
    required String contractId,
  }) {
    return _remoteDataSource.depositEscrow(
      amount: amount,
      contractId: contractId,
    );
  }

  @override
  Future<PaymentIntentResult> createPixPayment({
    String? contractId,
    required double amount,
    String? description,
    String? payerCpf,
    String? payerName,
  }) {
    return _remoteDataSource.createPixPayment(
      contractId: contractId,
      amount: amount,
      description: description,
      payerCpf: payerCpf,
      payerName: payerName,
    );
  }

  @override
  Future<PaymentIntentResult> createCreditCardPayment({
    String? contractId,
    required double amount,
    required CardPaymentData cardData,
    String? description,
  }) {
    return _remoteDataSource.createCreditCardPayment(
      contractId: contractId,
      amount: amount,
      cardData: cardData,
      description: description,
    );
  }

  @override
  Future<PaymentIntentResult> checkPaymentStatus({
    String? gatewayRef,
    String? transactionId,
  }) {
    return _remoteDataSource.checkPaymentStatus(
      gatewayRef: gatewayRef,
      transactionId: transactionId,
    );
  }

  @override
  Stream<WalletTransaction?> listenToTransaction(String transactionId) {
    return _remoteDataSource.listenToTransaction(transactionId);
  }
}
