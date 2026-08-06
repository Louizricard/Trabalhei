import '../entities/proposal.dart';

abstract class ProposalRepository {
  Future<List<Proposal>> getProposalsByJob(String jobId);
  Future<List<Proposal>> getFreelancerProposals(String freelancerId);
  Future<Proposal> submitProposal(Proposal proposal);
  Future<Map<String, dynamic>> acceptProposal(String proposalId);
  Future<void> rejectProposal(String proposalId);
  Future<void> makeCounterOffer({
    required String proposalId,
    required double counterPrice,
    required int counterEstimatedDays,
    String? counterMessage,
  });
  Future<void> acceptCounterOffer(String proposalId);
  Future<void> rejectCounterOffer(String proposalId);
}
