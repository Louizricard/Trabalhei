import 'dart:math' as math;
import '../../auth/domain/entities/user_profile.dart';

/// Ordenação "Mais relevantes" da busca de freelancers. Favorece qualidade
/// comprovada (nota ponderada pelo número de avaliações e trabalhos
/// concluídos) e compatibilidade com o que o cliente procura. O plano Pro não
/// dá prioridade: o selo indica só a assinatura.
List<UserProfile> rankFreelancers(
  List<UserProfile> profiles, {
  String? query,
  String? skill,
}) {
  final terms = {
    ...?query
        ?.toLowerCase()
        .split(RegExp(r'[\s,]+'))
        .where((t) => t.length >= 2),
    if (skill != null && skill.isNotEmpty && skill.toLowerCase() != 'todos')
      skill.toLowerCase(),
  };
  final scored = [
    for (final p in profiles) (profile: p, score: freelancerScore(p, terms)),
  ];
  scored.sort((a, b) => b.score.compareTo(a.score));
  return [for (final s in scored) s.profile];
}

/// Nota "bayesiana": poucas avaliações puxam a nota para perto da média
/// ([prior]), para 1 avaliação 5,0 não passar quem tem 30 avaliações 4,8.
double weightedRating(
  double rating,
  int reviews, {
  double prior = 4,
  int weight = 3,
}) => reviews <= 0
    ? prior - 0.5
    : (rating * reviews + prior * weight) / (reviews + weight);

double freelancerScore(UserProfile p, Set<String> terms) {
  final quality =
      weightedRating(p.rating, p.reviewsCount) * 2 +
      math.log(1 + p.completedJobsCount) / math.ln2;

  var compatibility = 0.0;
  if (terms.isNotEmpty) {
    final skills = p.skills.map((s) => s.toLowerCase()).toSet();
    final text = '${p.headline ?? ''} ${p.bio ?? ''}'.toLowerCase();
    for (final t in terms) {
      if (skills.contains(t)) {
        compatibility += 3;
      } else if (skills.any((s) => s.contains(t)) || text.contains(t)) {
        compatibility += 1;
      }
    }
  }

  var profile = 0.0;
  if ((p.bio ?? '').trim().length >= 100) profile += 0.5;
  if ((p.headline ?? '').trim().isNotEmpty) profile += 0.25;
  if ((p.avatarUrl ?? '').isNotEmpty) profile += 0.25;
  if (p.availabilityStatus == 'available') profile += 0.5;

  return quality + compatibility + profile;
}
