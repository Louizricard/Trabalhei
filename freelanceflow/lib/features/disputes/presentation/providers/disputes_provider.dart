import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_client.dart';
import '../../data/datasources/dispute_remote_data_source.dart';
import '../../data/repositories/dispute_repository_impl.dart';
import '../../domain/entities/dispute.dart';
import '../../domain/repositories/dispute_repository.dart';

final disputeRemoteDataSourceProvider = Provider<DisputeRemoteDataSource>((ref) {
  return DisputeRemoteDataSource(ref.watch(supabaseClientProvider));
});

final disputeRepositoryProvider = Provider<DisputeRepository>((ref) {
  return DisputeRepositoryImpl(ref.watch(disputeRemoteDataSourceProvider));
});

final contractDisputesProvider = FutureProvider.family<List<Dispute>, String>((ref, contractId) async {
  return ref.watch(disputeRepositoryProvider).getDisputesForContract(contractId);
});

final disputeDetailProvider = FutureProvider.family<Dispute?, String>((ref, disputeId) async {
  return ref.watch(disputeRepositoryProvider).getDisputeById(disputeId);
});
