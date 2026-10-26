import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_client.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../data/datasources/job_remote_data_source.dart';
import '../../data/repositories/job_repository_impl.dart';
import '../../domain/entities/job.dart';
import '../../domain/job_ranking.dart';
import '../../domain/repositories/job_repository.dart';

final jobDataSourceProvider = Provider<JobRemoteDataSource>((ref) {
  return JobRemoteDataSource(ref.watch(supabaseClientProvider));
});

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  return JobRepositoryImpl(ref.watch(jobDataSourceProvider));
});

/// Current filter state provider
final jobFilterProvider = StateProvider<JobFilter>((ref) => const JobFilter());

/// Jobs list notifier provider reacting to filters
final jobsListProvider = FutureProvider.autoDispose<List<Job>>((ref) async {
  final repository = ref.watch(jobRepositoryProvider);
  final filter = ref.watch(jobFilterProvider);
  final jobs = await repository.getJobs(filter: filter);
  if (filter.sortBy != 'relevance') return jobs;
  // Compatibilidade com as habilidades de quem está logado (visitante: só
  // qualidade e data).
  final skills = ref.watch(authProvider).valueOrNull?.skills ?? const [];
  return rankByRelevance(jobs, skills: skills);
});

/// Single job provider by ID
final jobDetailProvider = FutureProvider.family.autoDispose<Job?, String>((ref, id) async {
  final repository = ref.watch(jobRepositoryProvider);
  return repository.getJobById(id);
});

/// Vagas abertas do cliente logado (independe dos filtros do mural).
final myOpenJobsProvider = FutureProvider.autoDispose<List<Job>>((ref) async {
  final user = ref.watch(authProvider).value;
  if (user == null) return [];
  final jobs = await ref.watch(jobRepositoryProvider).getClientJobs(user.id);
  return jobs.where((j) => j.status == JobStatus.open).toList();
});
