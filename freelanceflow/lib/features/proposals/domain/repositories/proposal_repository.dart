import '../entities/proposal.dart';
import '../entities/proposal_quota.dart';

abstract class ProposalRepository {
  Future<List<Proposal>> getProposalsByJob(String jobId);
  Future<List<Proposal>> getFreelancerProposals(String freelancerId);
  Future<ProposalQuota> getQuota();
  Future<Proposal> submitProposal(Proposal proposal);
  Future<Map<String, dynamic>> acceptProposal(String proposalId);
  Future<void> rejectProposal(String proposalId);
  Future<void> makeCounterOffer({
    required String proposalId,
    required double counterPrice,
    required int counterEstimatedDays,
    String? counterMessage,
  });
  Future<Map<String, dynamic>> acceptCounterOffer(String proposalId);
  Future<void> rejectCounterOffer(String proposalId);
}
