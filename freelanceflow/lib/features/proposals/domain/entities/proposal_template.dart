/// Modelo reutilizável de proposta (recurso Pro): um texto base para a carta
/// de apresentação e, opcionalmente, o prazo habitual.
class ProposalTemplate {
  final String id;
  final String title;
  final String coverLetter;
  final int? estimatedDays;
  final DateTime updatedAt;

  const ProposalTemplate({
    required this.id,
    required this.title,
    required this.coverLetter,
    this.estimatedDays,
    required this.updatedAt,
  });

  factory ProposalTemplate.fromJson(Map<String, dynamic> json) =>
      ProposalTemplate(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        coverLetter: json['cover_letter'] as String? ?? '',
        estimatedDays: (json['estimated_days'] as num?)?.toInt(),
        updatedAt: DateTime.tryParse('${json['updated_at']}') ?? DateTime.now(),
      );
}
