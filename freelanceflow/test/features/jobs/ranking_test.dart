import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/features/auth/domain/entities/user_profile.dart';
import 'package:trabalhei/features/jobs/domain/entities/job.dart';
import 'package:trabalhei/features/jobs/domain/job_ranking.dart';
import 'package:trabalhei/features/profile/domain/freelancer_ranking.dart';

final _now = DateTime(2026, 10, 27, 12);

Job _job(
  String id, {
  List<String> skills = const [],
  double rating = 0,
  int ageDays = 1,
  DateTime? featuredUntil,
  String description = 'Projeto simples.',
}) => Job(
  id: id,
  clientId: 'c-$id',
  title: 'Vaga $id',
  description: description,
  category: 'Mobile',
  clientName: 'Cliente',
  clientRating: rating,
  budgetMin: 100,
  budgetMax: 1000,
  skillsRequired: skills,
  featuredUntil: featuredUntil,
  createdAt: _now.subtract(Duration(days: ageDays)),
);

void main() {
  group('rankByRelevance', () {
    test('compatibilidade com as habilidades vem primeiro', () {
      final ranked = rankByRelevance(
        [
          _job('a', skills: ['Design']),
          _job('b', skills: ['Flutter', 'Dart']),
        ],
        skills: ['flutter', 'dart'],
        now: _now,
      );
      expect(ranked.first.id, 'b');
    });

    test('pagar destaque não sobe a vaga na ordem normal', () {
      final ranked = rankByRelevance([
        _job('paga', featuredUntil: _now.add(const Duration(days: 3))),
        _job('boa', rating: 4.8, description: 'x' * 250),
      ], now: _now);
      expect(ranked.first.id, 'boa');
    });

    test('mais nova ganha no empate', () {
      final ranked = rankByRelevance([
        _job('velha', ageDays: 10),
        _job('nova', ageDays: 0),
      ], now: _now);
      expect(ranked.first.id, 'nova');
    });
  });

  group('splitSponsored', () {
    final featured = [
      for (final id in ['p1', 'p2', 'p3', 'p4'])
        _job(id, featuredUntil: _now.add(const Duration(days: 5))),
    ];
    final normal = [_job('n1'), _job('n2')];

    test('ocupa só os espaços e mantém as demais na lista', () {
      final split = splitSponsored(
        [...normal, ...featured],
        slots: 2,
        rotationMinutes: 60,
        now: _now,
      );
      expect(split.sponsored, hasLength(2));
      expect(split.rest, hasLength(4));
      expect(split.rest.where((j) => j.isFeatured), hasLength(2));
    });

    test('mesma rodada, mesma ordem; rodadas diferentes, rodízio', () {
      List<String> top(DateTime at) => splitSponsored(
        featured,
        slots: 2,
        rotationMinutes: 60,
        now: at,
      ).sponsored.map((j) => j.id).toList();
      expect(top(_now), top(_now.add(const Duration(minutes: 5))));
      // Ao longo de um dia, todas as patrocinadas passam pelo topo.
      final seen = <String>{
        for (var h = 0; h < 24; h++) ...top(_now.add(Duration(hours: h))),
      };
      expect(seen, containsAll(['p1', 'p2', 'p3', 'p4']));
    });

    test('sem espaços, nada vai para o topo', () {
      final split = splitSponsored(
        featured,
        slots: 0,
        rotationMinutes: 60,
        now: _now,
      );
      expect(split.sponsored, isEmpty);
      expect(split.rest, hasLength(4));
    });
  });

  group('rankFreelancers', () {
    UserProfile p(
      String id, {
      double rating = 0,
      int reviews = 0,
      int done = 0,
      List<String> skills = const [],
      String plan = 'free',
    }) => UserProfile(
      id: id,
      email: '',
      fullName: id,
      role: UserRole.freelancer,
      rating: rating,
      reviewsCount: reviews,
      completedJobsCount: done,
      skills: skills,
      plan: plan,
      createdAt: _now,
    );

    test('Pro não ganha prioridade; avaliações comprovadas pesam mais', () {
      final ranked = rankFreelancers([
        p('pro', plan: 'pro'),
        p('experiente', rating: 4.8, reviews: 30, done: 25),
      ]);
      expect(ranked.first.id, 'experiente');
    });

    test('uma única nota 5 não passa quem tem muitas avaliações altas', () {
      expect(weightedRating(5, 1) < weightedRating(4.8, 30), isTrue);
    });

    test('compatibilidade com a busca', () {
      final ranked = rankFreelancers([
        p('design', rating: 4.5, reviews: 5, skills: ['Figma']),
        p('flutter', rating: 4.5, reviews: 5, skills: ['Flutter']),
      ], query: 'flutter');
      expect(ranked.first.id, 'flutter');
    });
  });
}
