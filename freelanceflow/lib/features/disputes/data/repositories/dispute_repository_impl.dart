import '../../domain/entities/dispute.dart';
import '../../domain/repositories/dispute_repository.dart';
import '../datasources/dispute_remote_data_source.dart';

class DisputeRepositoryImpl implements DisputeRepository {
  final DisputeRemoteDataSource _remoteDataSource;

  DisputeRepositoryImpl(this._remoteDataSource);

  @override
  Future<Dispute> openDispute({
    required String contractId,
    String? milestoneId,
    required String reason,
    required String description,
    List<Map<String, dynamic>> evidenceAttachments = const [],
    String? conversationId,
  }) {
    return _remoteDataSource.openDispute(
      contractId: contractId,
      milestoneId: milestoneId,
      reason: reason,
      description: description,
      evidenceAttachments: evidenceAttachments,
      conversationId: conversationId,
    );
  }

  @override
  Future<List<Dispute>> getDisputesForContract(String contractId) {
    return _remoteDataSource.getDisputesForContract(contractId);
  }

  @override
  Future<Dispute?> getDisputeById(String id) {
    return _remoteDataSource.getDisputeById(id);
  }

  @override
  Future<void> addDisputeMessage({
    required String disputeId,
    required String message,
    List<Map<String, dynamic>> attachments = const [],
  }) {
    return _remoteDataSource.addDisputeMessage(
      disputeId: disputeId,
      message: message,
      attachments: attachments,
    );
  }
}
