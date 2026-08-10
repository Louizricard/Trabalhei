import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_client.dart';
import '../../data/datasources/proposal_remote_data_source.dart';
import '../../data/repositories/proposal_repository_impl.dart';
import '../../domain/entities/proposal.dart';
import '../../domain/repositories/proposal_repository.dart';

final proposalDataSourceProvider = Provider<ProposalRemoteDataSource>((ref) {
  return ProposalRemoteDataSource(ref.watch(supabaseClientProvider));
});

final proposalRepositoryProvider = Provider<ProposalRepository>((ref) {
  return ProposalRepositoryImpl(ref.watch(proposalDataSourceProvider));
});

final jobProposalsProvider = FutureProvider.family.autoDispose<List<Proposal>, String>((
  ref,
  jobId,
) async {
  final repository = ref.watch(proposalRepositoryProvider);
  return repository.getProposalsByJob(jobId);
});

final freelancerProposalsProvider =
    FutureProvider.family.autoDispose<List<Proposal>, String>((ref, freelancerId) async {
      final repository = ref.watch(proposalRepositoryProvider);
      return repository.getFreelancerProposals(freelancerId);
    });
