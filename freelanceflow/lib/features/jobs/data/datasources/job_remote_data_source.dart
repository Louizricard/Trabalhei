import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/job.dart';
import '../../domain/repositories/job_repository.dart';

class JobRemoteDataSource {
  final SupabaseClient _supabase;

  JobRemoteDataSource(this._supabase);

  Future<List<Job>> getJobs({JobFilter? filter}) async {
    var query = _supabase
        .from('jobs')
        .select('*, proposals_count, profiles!client_id(full_name, rating)')
        .eq('status', 'open');

    if (filter != null) {
      if (filter.category != null && filter.category != 'Todas') {
        query = query.ilike('category', filter.category!);
      }
      if (filter.experienceLevel != null &&
          filter.experienceLevel != ExperienceLevel.all) {
        // Vagas abertas a todos os níveis também servem.
        query = query.inFilter('experience_level', [
          filter.experienceLevel!.name,
          ExperienceLevel.all.name,
        ]);
      }
      if (filter.minBudget != null) {
        query = query.gte('budget_max', filter.minBudget!);
      }
      if (filter.maxBudget != null) {
        query = query.lte('budget_min', filter.maxBudget!);
      }
      if (filter.contractType != null) {
        query = query.eq('contract_type', filter.contractType!.name);
      }
      if (filter.maxDeadlineDays != null) {
        query = query.lte('deadline_days', filter.maxDeadlineDays!);
      }
      if (filter.urgentOnly) {
        query = query.eq('is_urgent', true);
      }
      if (filter.searchQuery != null && filter.searchQuery!.trim().isNotEmpty) {
        final term = '%${filter.searchQuery!.trim()}%';
        query = query.or('title.ilike.$term,description.ilike.$term');
      }
    }

    final response = await query.order('created_at', ascending: false);
    final List<dynamic> data = response as List<dynamic>;

    final minRating = filter?.minClientRating;
    final list = data
        .map((json) => Job.fromJson(json as Map<String, dynamic>))
        // A nota vem do perfil do cliente (embed), filtrada aqui.
        .where((j) => minRating == null || j.clientRating >= minRating)
        .toList();

    // "Mais relevantes" depende das habilidades de quem procura e é aplicada
    // no provider; vagas patrocinadas não sobem aqui (ver job_ranking.dart).
    if (filter?.sortBy == 'budget_desc') {
      list.sort((a, b) => b.budgetMax.compareTo(a.budgetMax));
    } else if (filter?.sortBy == 'proposals_asc') {
      list.sort((a, b) => a.proposalsCount.compareTo(b.proposalsCount));
    }
    return list;
  }

  Future<Job?> getJobById(String id) async {
    final response = await _supabase
        .from('jobs')
        .select('*, proposals_count, profiles!client_id(full_name, rating)')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Job.fromJson(response);
  }

  Future<Job> createJob(Job job) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');
    final response = await _supabase
        .from('jobs')
        .insert({...job.toWriteJson(), 'client_id': user.id})
        .select('*, profiles!client_id(full_name, rating)')
        .single();
    return Job.fromJson(response);
  }

  Future<Job> updateJob(Job job) async {
    final response = await _supabase
        .from('jobs')
        .update(job.toWriteJson())
        .eq('id', job.id)
        .select('*, profiles!client_id(full_name, rating)')
        .single();
    return Job.fromJson(response);
  }

  Future<void> cancelJob(String jobId) async {
    await _supabase.rpc('cancel_job', params: {'p_job_id': jobId});
  }

  Future<List<Job>> getClientJobs(String clientId) async {
    final response = await _supabase
        .from('jobs')
        .select('*, proposals_count, profiles!client_id(full_name, rating)')
        .eq('client_id', clientId)
        .order('created_at', ascending: false);

    final List<dynamic> data = response as List<dynamic>;
    return data
        .map((json) => Job.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
