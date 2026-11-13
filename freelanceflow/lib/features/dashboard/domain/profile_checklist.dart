import '../../auth/domain/entities/user_profile.dart';

/// Um passo do "Complete seu perfil": o que falta e onde resolver.
class ChecklistStep {
  final String label;
  final bool done;
  final String route;

  const ChecklistStep(this.label, {required this.done, required this.route});
}

/// Rota da edição de perfil.
const profileEditRoute = '/profile';

/// Passos do primeiro uso por papel, a partir de dados que o app já tem
/// (sem tabela nova). [hasJobs]: o contratante já publicou alguma vaga.
List<ChecklistStep> profileChecklist(UserProfile user, {bool hasJobs = false}) {
  final photo = ChecklistStep(
    user.role == UserRole.client
        ? 'Adicione uma foto ou logo'
        : 'Adicione uma foto',
    done: (user.avatarUrl ?? '').isNotEmpty,
    route: profileEditRoute,
  );
  if (user.role == UserRole.client) {
    return [
      photo,
      ChecklistStep(
        'Publique sua primeira vaga',
        done: hasJobs,
        route: '/jobs/create',
      ),
    ];
  }
  return [
    photo,
    ChecklistStep(
      'Escreva seu título profissional',
      done: (user.headline ?? '').trim().isNotEmpty,
      route: profileEditRoute,
    ),
    ChecklistStep(
      'Escolha sua área de atuação',
      done: user.category != null,
      route: profileEditRoute,
    ),
    ChecklistStep(
      'Adicione pelo menos 3 habilidades',
      done: user.skills.length >= 3,
      route: profileEditRoute,
    ),
    ChecklistStep(
      'Conte sua experiência na apresentação',
      done: (user.bio ?? '').trim().length >= 100,
      route: profileEditRoute,
    ),
  ];
}
