import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/errors/backend_errors.dart';
import '../domain/entities/bug_report.dart';
import '../domain/repositories/bug_report_repository.dart';

/// Relatórios na tabela `bug_reports`; capturas no bucket privado
/// `bug_reports`, em `<uid>/<id>.<ext>`. Só administradores leem.
class BugReportRepositoryImpl implements BugReportRepository {
  static const bucket = 'bug_reports';

  final SupabaseClient _supabase;

  BugReportRepositoryImpl(this._supabase);

  @override
  Future<void> submit(BugReport report) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw const AppMessageException('Entre na sua conta para enviar.');
    }

    String? path;
    final shot = report.screenshot;
    if (shot != null) {
      path = '$userId/${const Uuid().v4()}.${shot.extension}';
      await _supabase.storage
          .from(bucket)
          .uploadBinary(
            path,
            shot.bytes,
            fileOptions: FileOptions(contentType: shot.mimeType),
          );
    }

    try {
      await _supabase.from('bug_reports').insert({
        'description': report.description.trim(),
        'screenshot_path': path,
        'platform': report.platform,
        'app_version': report.appVersion,
      });
    } catch (_) {
      // Sem o registro, a captura ficaria solta no storage.
      if (path != null) {
        try {
          await _supabase.storage.from(bucket).remove([path]);
        } catch (_) {}
      }
      rethrow;
    }
  }
}
