import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/job.dart';
import '../../domain/repositories/job_repository.dart';

class JobRemoteDataSource {
  final SupabaseClient _supabase;

  JobRemoteDataSource(this._supabase);

  Future<List<Job>> getJobs({JobFilter? filter}) async {
    var query = _supabase
        .from('jobs')
        .select('*, profiles!client_id(full_name, rating), proposals(count)')
        .eq('status', 'open');

    if (filter != null) {
      if (filter.category != null && filter.category != 'Todas') {
        query = query.ilike('category', filter.category!);
      }
      if (filter.experienceLevel != null &&
          filter.experienceLevel != ExperienceLevel.all) {
        query = query.eq('experience_level', filter.experienceLevel!.name);
      }
      if (filter.minBudget != null) {
        query = query.gte('budget_max', filter.minBudget!);
      }
      if (filter.maxBudget != null) {
        query = query.lte('budget_min', filter.maxBudget!);
      }
      if (filter.searchQuery != null && filter.searchQuery!.trim().isNotEmpty) {
        final term = '%${filter.searchQuery!.trim()}%';
        query = query.or('title.ilike.$term,description.ilike.$term');
      }
    }

    final response = await query.order('created_at', ascending: false);
    final List<dynamic> data = response as List<dynamic>;

    var list = data
        .map((json) => Job.fromJson(json as Map<String, dynamic>))
        .toList();

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
        .select('*, profiles!client_id(full_name, rating), proposals(count)')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Job.fromJson(response);
  }

  Future<Job> createJob(Job job) async {
    final user = _supabase.auth.currentUser;
    final payload = job.toJson();
    if (user != null) {
      payload['client_id'] = user.id;
    }
    // Remove client-generated id if not valid uuid or let supabase generate default gen_random_uuid
    if (!payload['id'].toString().contains('-') ||
        payload['id'].toString().startsWith('job-')) {
      payload.remove('id');
    }

    final response = await _supabase
        .from('jobs')
        .insert(payload)
        .select('*, profiles!client_id(full_name, rating)')
        .single();
    return Job.fromJson(response);
  }

  Future<List<Job>> getClientJobs(String clientId) async {
    final response = await _supabase
        .from('jobs')
        .select('*, profiles!client_id(full_name, rating), proposals(count)')
        .eq('client_id', clientId)
        .order('created_at', ascending: false);

    final List<dynamic> data = response as List<dynamic>;
    return data
        .map((json) => Job.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
