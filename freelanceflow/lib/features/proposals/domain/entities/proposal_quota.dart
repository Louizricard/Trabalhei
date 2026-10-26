/// Saldo de propostas do mês e teto diário (função `proposal_quota` do banco).
/// Propostas para vagas canceladas, removidas pela moderação ou sem resposta
/// do cliente depois de alguns dias voltam ao saldo ([refunded]).
class ProposalQuota {
  final bool isPro;
  final int monthlyLimit;
  final int used;
  final int refunded;
  final int dailyLimit;
  final int usedToday;
  final int minCoverLetterChars;

  const ProposalQuota({
    required this.isPro,
    required this.monthlyLimit,
    required this.used,
    this.refunded = 0,
    this.dailyLimit = 15,
    this.usedToday = 0,
    this.minCoverLetterChars = 50,
  });

  int get remaining => (monthlyLimit - used).clamp(0, monthlyLimit);
  int get remainingToday => (dailyLimit - usedToday).clamp(0, dailyLimit);
  bool get isExhausted => remaining <= 0;
  bool get isDailyLimitReached => remainingToday <= 0;

  factory ProposalQuota.fromJson(Map<String, dynamic> json) {
    int read(String key, int fallback) =>
        (json[key] as num?)?.toInt() ?? fallback;
    return ProposalQuota(
      isPro: json['is_pro'] as bool? ?? false,
      monthlyLimit: read('monthly_limit', 10),
      used: read('used', 0),
      refunded: read('refunded', 0),
      dailyLimit: read('daily_limit', 15),
      usedToday: read('used_today', 0),
      minCoverLetterChars: read('min_cover_letter_chars', 50),
    );
  }
}
