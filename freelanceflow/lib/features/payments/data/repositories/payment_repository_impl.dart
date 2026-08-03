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
  Future<void> requestPixWithdrawal({required double amount, required String pixKey}) {
    return _remoteDataSource.requestPixWithdrawal(amount: amount, pixKey: pixKey);
  }

  @override
  Future<void> depositEscrow({required double amount, required String contractId}) {
    return _remoteDataSource.depositEscrow(amount: amount, contractId: contractId);
  }
}
