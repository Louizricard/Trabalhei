import '../entities/dispute.dart';

abstract class DisputeRepository {
  Future<Dispute> openDispute({
    required String contractId,
    String? milestoneId,
    required String reason,
    required String description,
    List<Map<String, dynamic>> evidenceAttachments = const [],
    String? conversationId,
  });

  Future<List<Dispute>> getDisputesForContract(String contractId);
  Future<Dispute?> getDisputeById(String id);
  Future<void> addDisputeMessage({
    required String disputeId,
    required String message,
    List<Map<String, dynamic>> attachments = const [],
  });
}
