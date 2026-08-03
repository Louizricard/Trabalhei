import '../entities/job.dart';

class JobFilter {
  final String? searchQuery;
  final String? category;
  final double? minBudget;
  final double? maxBudget;
  final ExperienceLevel? experienceLevel;
  final String sortBy; // 'recent', 'budget_desc', 'proposals_asc'

  const JobFilter({
    this.searchQuery,
    this.category,
    this.minBudget,
    this.maxBudget,
    this.experienceLevel,
    this.sortBy = 'recent',
  });

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
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

abstract class JobRepository {
  Future<List<Job>> getJobs({JobFilter? filter});
  Future<Job?> getJobById(String id);
  Future<Job> createJob(Job job);
  Future<List<Job>> getClientJobs(String clientId);
}
