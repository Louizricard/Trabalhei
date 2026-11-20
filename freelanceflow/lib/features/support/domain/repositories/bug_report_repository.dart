import '../entities/bug_report.dart';

abstract class BugReportRepository {
  /// Guarda o relatório (e a captura, se houver) em nome do usuário logado.
  Future<void> submit(BugReport report);
}
