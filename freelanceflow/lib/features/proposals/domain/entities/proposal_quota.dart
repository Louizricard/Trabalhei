/// Cota mensal de propostas do usuário (plano grátis x Pro).
class ProposalQuota {
  final bool isPro;

  /// `null` quando ilimitado (Pro).
  final int? monthlyLimit;
  final int used;

  const ProposalQuota({
    required this.isPro,
    required this.monthlyLimit,
    required this.used,
  });

  bool get isUnlimited => monthlyLimit == null;
  int? get remaining =>
      monthlyLimit == null ? null : (monthlyLimit! - used).clamp(0, 1 << 30);
  bool get isExhausted => remaining != null && remaining! <= 0;

  factory ProposalQuota.fromJson(Map<String, dynamic> json) {
    return ProposalQuota(
      isPro: json['is_pro'] as bool? ?? false,
      monthlyLimit: (json['monthly_limit'] as num?)?.toInt(),
      used: (json['used'] as num?)?.toInt() ?? 0,
    );
  }
}
