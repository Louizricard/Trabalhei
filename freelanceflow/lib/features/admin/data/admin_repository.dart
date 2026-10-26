import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/admin_models.dart';

/// Moderação. Todas as funções do banco conferem se quem chama é administrador
/// (`FORBIDDEN` caso contrário); denunciar é aberto a qualquer usuário logado.
class AdminRepository {
  final SupabaseClient _supabase;

  AdminRepository(this._supabase);

  Future<bool> isAdmin() async {
    if (_supabase.auth.currentUser == null) return false;
    return await _supabase.rpc('is_admin') as bool? ?? false;
  }

  Future<AdminOverview> overview() async => AdminOverview.fromJson(
    Map<String, dynamic>.from(await _supabase.rpc('admin_overview') as Map),
  );

  Future<List<AdminReport>> reports(String status) async {
    final rows =
        await _supabase.rpc('admin_list_reports', params: {'p_status': status})
            as List;
    return rows
        .map((r) => AdminReport.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> resolveReport(String reportId, {required bool dismiss}) =>
      _supabase.rpc(
        'admin_resolve_report',
        params: {
          'p_report_id': reportId,
          'p_status': dismiss ? 'dismissed' : 'resolved',
        },
      );

  Future<List<AdminUser>> users(String query) async {
    final rows =
        await _supabase.rpc('admin_search_users', params: {'p_query': query})
            as List;
    return rows
        .map((r) => AdminUser.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> suspendUser(String userId, String reason) => _supabase.rpc(
    'admin_suspend_user',
    params: {'p_user_id': userId, 'p_reason': reason},
  );

  Future<void> unsuspendUser(String userId) =>
      _supabase.rpc('admin_unsuspend_user', params: {'p_user_id': userId});

  Future<List<AdminJob>> jobs(String query) async {
    final rows =
        await _supabase.rpc('admin_list_jobs', params: {'p_query': query})
            as List;
    return rows
        .map((r) => AdminJob.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> removeJob(String jobId, String reason) => _supabase.rpc(
    'admin_remove_job',
    params: {'p_job_id': jobId, 'p_reason': reason},
  );

  /// Denúncia de uma vaga ou de um perfil.
  Future<void> report({
    required ReportTarget target,
    required String targetId,
    required ReportReason reason,
    String? details,
  }) async {
    await _supabase.from('reports').insert({
      'target_type': target.name,
      'target_id': targetId,
      'reason': reason.dbValue,
      if (details != null && details.trim().isNotEmpty)
        'details': details.trim(),
    });
  }
}
