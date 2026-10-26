import '../entities/job.dart';

/// Filtros do mural. Campos nulos não filtram.
class JobFilter {
  final String? searchQuery;
  final String? category;
  final double? minBudget;
  final double? maxBudget;
  final ExperienceLevel? experienceLevel;
  final ContractType? contractType;
  final int? maxDeadlineDays;

  /// Nota mínima do cliente (0 a 5).
  final double? minClientRating;
  final bool urgentOnly;
  /// 'relevance' (compatibilidade e qualidade), 'recent', 'budget_desc' ou
  /// 'proposals_asc'.
  final String sortBy;

  const JobFilter({
    this.searchQuery,
    this.category,
    this.minBudget,
    this.maxBudget,
    this.experienceLevel,
    this.contractType,
    this.maxDeadlineDays,
    this.minClientRating,
    this.urgentOnly = false,
    this.sortBy = 'relevance',
  });

  /// Quantos filtros avançados estão ligados (para o selo no botão).
  int get activeCount => [
    experienceLevel != null && experienceLevel != ExperienceLevel.all,
    contractType != null,
    minBudget != null,
    maxBudget != null,
    maxDeadlineDays != null,
    minClientRating != null,
    urgentOnly,
    sortBy != 'relevance',
  ].where((on) => on).length;

  JobFilter copyWith({
    String? searchQuery,
    String? category,
    double? minBudget,
    double? maxBudget,
    ExperienceLevel? experienceLevel,
    String? sortBy,
  }) {
    return JobFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      category: category ?? this.category,
      minBudget: minBudget ?? this.minBudget,
      maxBudget: maxBudget ?? this.maxBudget,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      contractType: contractType,
      maxDeadlineDays: maxDeadlineDays,
      minClientRating: minClientRating,
      urgentOnly: urgentOnly,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

abstract class JobRepository {
  Future<List<Job>> getJobs({JobFilter? filter});
  Future<Job?> getJobById(String id);
  Future<Job> createJob(Job job);
  Future<Job> updateJob(Job job);
  Future<void> cancelJob(String jobId);
  Future<List<Job>> getClientJobs(String clientId);
}
