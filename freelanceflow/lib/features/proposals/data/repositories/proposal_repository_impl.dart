import '../../domain/entities/proposal.dart';
import '../../domain/repositories/proposal_repository.dart';
import '../datasources/proposal_remote_data_source.dart';

class ProposalRepositoryImpl implements ProposalRepository {
  final ProposalRemoteDataSource _remoteDataSource;

  ProposalRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<Proposal>> getProposalsByJob(String jobId) {
    return _remoteDataSource.getProposalsByJob(jobId);
  }

  @override
  Future<List<Proposal>> getFreelancerProposals(String freelancerId) {
    return _remoteDataSource.getFreelancerProposals(freelancerId);
  }

  @override
  Future<Proposal> submitProposal(Proposal proposal) {
    return _remoteDataSource.submitProposal(proposal);
  }

  @override
  Future<void> acceptProposal(String proposalId) {
    return _remoteDataSource.updateStatus(proposalId, ProposalStatus.accepted);
  }

  @override
  Future<void> rejectProposal(String proposalId) {
    return _remoteDataSource.updateStatus(proposalId, ProposalStatus.rejected);
  }
}
