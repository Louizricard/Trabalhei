import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trabalhei/core/errors/backend_errors.dart';
import 'package:trabalhei/features/admin/domain/admin_models.dart';
import 'package:trabalhei/features/jobs/domain/entities/job.dart';
import 'package:trabalhei/features/jobs/domain/entities/job_alert.dart';
import 'package:trabalhei/features/jobs/domain/repositories/job_repository.dart';
import 'package:trabalhei/features/notifications/domain/entities/app_notification.dart';

void main() {
  group('JobFilter', () {
    test('conta só os filtros avançados ligados', () {
      expect(const JobFilter().activeCount, 0);
      expect(
        const JobFilter(
          experienceLevel: ExperienceLevel.all,
          category: 'Mobile',
        ).activeCount,
        0,
      );
      expect(
        const JobFilter(
          experienceLevel: ExperienceLevel.pleno,
          contractType: ContractType.hourly,
          minBudget: 500,
          maxDeadlineDays: 30,
          minClientRating: 4,
          urgentOnly: true,
          sortBy: 'budget_desc',
        ).activeCount,
        7,
      );
    });
  });

  group('JobAlert', () {
    test('grava os filtros do mural, sem campos vazios', () {
      final json = JobAlert.insertJson(
        name: '  Apps Flutter ',
        filter: const JobFilter(
          experienceLevel: ExperienceLevel.all,
          contractType: ContractType.fixed,
          minBudget: 1000,
          urgentOnly: true,
        ),
        query: '  flutter ',
        category: 'Mobile',
      );
      expect(json, {
        'name': 'Apps Flutter',
        'query': 'flutter',
        'category': 'Mobile',
        'experience_level': null,
        'contract_type': 'fixed',
        'min_budget': 1000.0,
        'max_deadline_days': null,
        'urgent_only': true,
      });
    });

    test('resume os critérios em português', () {
      final alert = JobAlert.fromJson({
        'id': 'a1',
        'name': 'Apps',
        'query': 'flutter',
        'category': 'Mobile',
        'experience_level': 'senior',
        'contract_type': 'hourly',
        'max_deadline_days': 15,
        'urgent_only': true,
        'created_at': '2026-10-26T10:00:00Z',
      });
      expect(
        alert.describe(),
        '"flutter" · Mobile · Sênior · Por hora · prazo até 15 dias · só urgentes',
      );
      expect(
        JobAlert.fromJson({'id': 'a2', 'name': 'Tudo'}).describe(),
        'Qualquer vaga nova',
      );
    });
  });

  test('notificação de alerta de vaga tem tipo próprio', () {
    expect(NotificationType.fromString('job_alert'), NotificationType.jobAlert);
    expect(NotificationType.jobAlert.toDbString(), 'job_alert');
  });

  group('moderação', () {
    test('lê denúncia e usuário do painel', () {
      final report = AdminReport.fromJson({
        'id': 'r1',
        'target_type': 'job',
        'target_id': 'j1',
        'target_label': 'Logo',
        'reason': 'off_platform_payment',
        'status': 'open',
        'created_at': '2026-10-26T10:00:00Z',
        'reports_on_target': 3,
      });
      expect(report.target, ReportTarget.job);
      expect(report.reason, ReportReason.offPlatformPayment);
      expect(report.reportsOnTarget, 3);

      final user = AdminUser.fromJson({
        'id': 'u1',
        'full_name': 'Ana',
        'email': 'ana@exemplo.com',
        'created_at': '2026-10-01T10:00:00Z',
        'suspended_at': '2026-10-26T10:00:00Z',
      });
      expect(user.isSuspended, isTrue);
      expect(ReportReason.fromDb('desconhecido'), ReportReason.other);
    });

    test('erros da moderação e denúncia repetida viram mensagens claras', () {
      expect(
        friendlyError(
          const PostgrestException(message: 'CANNOT_MODERATE_SELF'),
        ),
        'Você não pode moderar a própria conta.',
      );
      expect(
        friendlyError(
          const PostgrestException(
            code: '23505',
            message:
                'duplicate key value violates unique constraint "reports_one_open_per_target"',
          ),
        ),
        'Você já denunciou isto. A moderação vai analisar em breve.',
      );
      expect(
        friendlyError(
          const AuthException('User is banned', code: 'user_banned'),
        ),
        contains('suspensa'),
      );
    });
  });
}
