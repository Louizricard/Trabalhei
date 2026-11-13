import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/features/auth/domain/entities/user_profile.dart';
import 'package:trabalhei/features/dashboard/domain/profile_checklist.dart';

UserProfile _user(
  UserRole role, {
  String? category,
  List<String> skills = const [],
}) => UserProfile(
  id: 'u1',
  email: 'a@b.com',
  fullName: 'Ana',
  role: role,
  category: category,
  skills: skills,
  createdAt: DateTime(2026),
);

void main() {
  test('freelancer novo vê área e habilidades como pendentes', () {
    final steps = profileChecklist(_user(UserRole.freelancer));
    expect(
      steps.where((s) => !s.done).map((s) => s.label),
      containsAll([
        'Escolha sua área de atuação',
        'Adicione pelo menos 3 habilidades',
      ]),
    );
  });

  test('freelancer com área e 3 habilidades marca esses passos', () {
    final steps = profileChecklist(
      _user(UserRole.freelancer, category: 'Design', skills: ['a', 'b', 'c']),
    );
    expect(steps.firstWhere((s) => s.label.contains('área')).done, isTrue);
    expect(
      steps.firstWhere((s) => s.label.contains('habilidades')).done,
      isTrue,
    );
  });

  test('contratante: publicar a primeira vaga leva ao formulário', () {
    final pending = profileChecklist(_user(UserRole.client)).last;
    expect(pending.route, '/jobs/create');
    expect(pending.done, isFalse);
    expect(
      profileChecklist(_user(UserRole.client), hasJobs: true).last.done,
      isTrue,
    );
  });
}
