import '../entities/proposal.dart';

abstract class ProposalRepository {
  Future<List<Proposal>> getProposalsByJob(String jobId);
  Future<List<Proposal>> getFreelancerProposals(String freelancerId);
  Future<Proposal> submitProposal(Proposal proposal);
  Future<void> acceptProposal(String proposalId);
  Future<void> rejectProposal(String proposalId);
}
