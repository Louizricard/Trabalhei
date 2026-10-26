import 'dart:math' as math;
import 'entities/job.dart';

/// Ordenação "Mais relevantes" do mural: favorece compatibilidade (habilidades
/// em comum com quem procura) e qualidade da vaga (cliente bem avaliado,
/// descrição completa, orçamento informado), com um bônus para vagas novas.
/// Pagamento não entra na conta: vagas patrocinadas aparecem identificadas em
/// um espaço próprio (ver [splitSponsored]).
List<Job> rankByRelevance(
  List<Job> jobs, {
  Iterable<String> skills = const [],
  DateTime? now,
}) {
  final mine = skills
      .map((s) => s.trim().toLowerCase())
      .where((s) => s.isNotEmpty)
      .toSet();
  final at = now ?? DateTime.now();
  final scored = [
    for (final job in jobs) (job: job, score: relevanceScore(job, mine, at)),
  ];
  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : b.job.createdAt.compareTo(a.job.createdAt);
  });
  return [for (final s in scored) s.job];
}

/// Pontuação de uma vaga para quem tem as habilidades [skills] (minúsculas).
double relevanceScore(Job job, Set<String> skills, DateTime now) {
  final matches = job.skillsRequired
      .where((s) => skills.contains(s.trim().toLowerCase()))
      .length;
  final compatibility = math.min(matches, 4) * 3.0;

  var quality = 0.0;
  if (job.clientRating >= 4.5) {
    quality += 1.5;
  } else if (job.clientRating >= 4) {
    quality += 1;
  } else if (job.clientRating >= 3) {
    quality += 0.5;
  }
  if (job.description.trim().length >= 200) quality += 0.5;
  if (job.budgetMax > 0) quality += 0.5;

  final ageDays = now.difference(job.createdAt).inHours / 24;
  final freshness = math.max(0, 2 - ageDays / 7);

  return compatibility + quality + freshness;
}

/// Vagas patrocinadas do topo e o restante do mural.
class SponsoredSplit {
  final List<Job> sponsored;
  final List<Job> rest;

  const SponsoredSplit(this.sponsored, this.rest);
}

/// Separa até [slots] vagas patrocinadas para o topo. Quando há mais vagas
/// patrocinadas que espaços, elas se revezam: a cada [rotationMinutes] a fila
/// anda (igual para todo mundo naquela rodada), então todas recebem o mesmo
/// tempo no topo. As que ficam fora do topo seguem na posição normal,
/// também identificadas como patrocinadas.
SponsoredSplit splitSponsored(
  List<Job> jobs, {
  required int slots,
  required int rotationMinutes,
  DateTime? now,
}) {
  final featured = jobs.where((j) => j.isFeatured).toList();
  if (slots <= 0 || featured.isEmpty) return SponsoredSplit(const [], jobs);
  // Fila em ordem fixa (pelo id) que anda [slots] posições a cada rodada:
  // todas as patrocinadas passam pelo topo e ficam lá o mesmo tempo.
  featured.sort((a, b) => a.id.compareTo(b.id));
  final round =
      (now ?? DateTime.now()).millisecondsSinceEpoch ~/
      (math.max(rotationMinutes, 1) * 60000);
  final n = featured.length;
  final start = n <= slots ? 0 : (round * slots) % n;
  final top = [
    for (var i = 0; i < math.min(slots, n); i++) featured[(start + i) % n],
  ];
  final topIds = {for (final j in top) j.id};
  return SponsoredSplit(top, [
    for (final j in jobs)
      if (!topIds.contains(j.id)) j,
  ]);
}
