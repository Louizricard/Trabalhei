/// Avaliação que o usuário logado deixou em um contrato.
class ContractReview {
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const ContractReview({
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory ContractReview.fromJson(Map<String, dynamic> json) => ContractReview(
    rating: (json['rating'] as num).toInt(),
    comment: json['comment'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  );
}
