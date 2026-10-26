import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/features/auth/presentation/guest_access.dart';
import 'package:trabalhei/features/jobs/domain/entities/job.dart';

void main() {
  group('isPublicRoute', () {
    test(
      'visitante abre o mural, as vagas, perfis e a busca de freelancers',
      () {
        expect(isPublicRoute('/jobs'), isTrue);
        expect(isPublicRoute('/jobs/abc-123'), isTrue);
        expect(isPublicRoute('/profile/abc-123'), isTrue);
        expect(isPublicRoute('/freelancers'), isTrue);
      },
    );

    test('ações e áreas da conta pedem login', () {
      for (final route in [
        '/jobs/create',
        '/jobs/abc/apply',
        '/jobs/abc/proposals',
        '/jobs/abc/edit',
        '/profile',
        '/chat',
        '/chat/abc',
        '/dashboard',
        '/notifications',
        '/plans',
        '/',
      ]) {
        expect(isPublicRoute(route), isFalse, reason: route);
      }
    });
  });

  group('safeReturnPath', () {
    test('volta para a tela de origem dentro do app', () {
      expect(safeReturnPath('/jobs/abc/apply'), '/jobs/abc/apply');
      expect(safeReturnPath('/profile/abc'), '/profile/abc');
    });

    test('sem origem válida, vai para o mural', () {
      expect(safeReturnPath(null), '/jobs');
      expect(safeReturnPath(''), '/jobs');
      expect(safeReturnPath('https://exemplo.com'), '/jobs');
      expect(safeReturnPath('//exemplo.com'), '/jobs');
      expect(safeReturnPath('/login?from=/chat'), '/jobs');
      expect(safeReturnPath('/register'), '/jobs');
    });

    test('authRouteReturningTo codifica a origem', () {
      expect(
        authRouteReturningTo('/login', '/jobs/a?x=1'),
        '/login?from=%2Fjobs%2Fa%3Fx%3D1',
      );
    });
  });

  test('a contagem de propostas vem do campo calculado do banco', () {
    final job = Job.fromJson({
      'id': 'j1',
      'client_id': 'c1',
      'title': 'Landing page',
      'category': 'Frontend',
      'description': 'Uma landing page.',
      'status': 'open',
      'created_at': '2026-10-01T10:00:00Z',
      'proposals_count': 7,
      'proposals': [
        {'count': 1},
      ],
    });
    expect(job.proposalsCount, 7);
  });
}
