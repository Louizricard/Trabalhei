import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/entities/job_alert.dart';

class JobAlertRepository {
  final SupabaseClient _supabase;

  JobAlertRepository(this._supabase);

  Future<List<JobAlert>> list() async {
    final rows = await _supabase
        .from('job_alerts')
        .select()
        .order('created_at', ascending: false);
    return rows.map(JobAlert.fromJson).toList();
  }

  Future<void> create(Map<String, dynamic> fields) =>
      _supabase.from('job_alerts').insert(fields);

  Future<void> setActive(String id, bool active) =>
      _supabase.from('job_alerts').update({'is_active': active}).eq('id', id);

  Future<void> delete(String id) =>
      _supabase.from('job_alerts').delete().eq('id', id);
}
