import '../../domain/entities/job.dart';
import '../../domain/repositories/job_repository.dart';
import '../datasources/job_remote_data_source.dart';

class JobRepositoryImpl implements JobRepository {
  final JobRemoteDataSource _remoteDataSource;

  JobRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<Job>> getJobs({JobFilter? filter}) {
    return _remoteDataSource.getJobs(filter: filter);
  }

  @override
  Future<Job?> getJobById(String id) {
    return _remoteDataSource.getJobById(id);
  }

  @override
  Future<Job> createJob(Job job) {
    return _remoteDataSource.createJob(job);
  }

  @override
  Future<Job> updateJob(Job job) {
    return _remoteDataSource.updateJob(job);
  }

  @override
  Future<void> cancelJob(String jobId) {
    return _remoteDataSource.cancelJob(jobId);
  }

  @override
  Future<List<Job>> getClientJobs(String clientId) {
    return _remoteDataSource.getClientJobs(clientId);
  }
}
