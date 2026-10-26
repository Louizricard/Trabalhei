/// Preços e limites da plataforma. A fonte de verdade são as tabelas
/// `billing_products` e `platform_settings` do banco (ver
/// docs/monetizacao.md); os valores daqui só valem enquanto elas carregam ou
/// se a leitura falhar, e devem acompanhar a migração que as criou.
library;

class PlatformSettings {
  final int freeMonthlyProposals;
  final int proMonthlyProposals;
  final int dailyProposals;
  final int minCoverLetterChars;
  final int unansweredRefundDays;
  final int sponsoredSlots;
  final int sponsoredRotationMinutes;
  final int freeFileMb;
  final int proFileMb;
  final int maxProposalTemplates;

  const PlatformSettings({
    this.freeMonthlyProposals = 10,
    this.proMonthlyProposals = 50,
    this.dailyProposals = 15,
    this.minCoverLetterChars = 50,
    this.unansweredRefundDays = 14,
    this.sponsoredSlots = 2,
    this.sponsoredRotationMinutes = 60,
    this.freeFileMb = 10,
    this.proFileMb = 50,
    this.maxProposalTemplates = 20,
  });

  factory PlatformSettings.fromJson(Map<String, dynamic> json) {
    int read(String key, int fallback) =>
        (json[key] as num?)?.toInt() ?? fallback;
    const d = PlatformSettings();
    return PlatformSettings(
      freeMonthlyProposals: read(
        'free_monthly_proposals',
        d.freeMonthlyProposals,
      ),
      proMonthlyProposals: read('pro_monthly_proposals', d.proMonthlyProposals),
      dailyProposals: read('daily_proposals', d.dailyProposals),
      minCoverLetterChars: read(
        'min_cover_letter_chars',
        d.minCoverLetterChars,
      ),
      unansweredRefundDays: read(
        'unanswered_refund_days',
        d.unansweredRefundDays,
      ),
      sponsoredSlots: read('sponsored_slots', d.sponsoredSlots),
      sponsoredRotationMinutes: read(
        'sponsored_rotation_minutes',
        d.sponsoredRotationMinutes,
      ),
      freeFileMb: read('free_file_mb', d.freeFileMb),
      proFileMb: read('pro_file_mb', d.proFileMb),
      maxProposalTemplates: read(
        'max_proposal_templates',
        d.maxProposalTemplates,
      ),
    );
  }

  /// Tamanho máximo por arquivo enviado (chat, entregas e anexos de vaga).
  int fileLimitBytes({required bool isPro}) =>
      (isPro ? proFileMb : freeFileMb) * 1024 * 1024;
}

/// Produto cobrado: assinatura Pro ou destaque de projeto.
class BillingProduct {
  final String code;
  final String name;
  final double price;
  final int periodDays;

  const BillingProduct({
    required this.code,
    required this.name,
    required this.price,
    required this.periodDays,
  });

  factory BillingProduct.fromJson(Map<String, dynamic> json) => BillingProduct(
    code: json['code'] as String,
    name: json['name'] as String? ?? '',
    price: (json['price'] as num?)?.toDouble() ?? 0,
    periodDays: (json['period_days'] as num?)?.toInt() ?? 30,
  );
}

class Pricing {
  final BillingProduct pro;
  final BillingProduct feature;
  final PlatformSettings settings;

  const Pricing({
    required this.pro,
    required this.feature,
    required this.settings,
  });

  static const fallback = Pricing(
    pro: BillingProduct(
      code: 'pro_monthly',
      name: 'Trabalhei Pro',
      price: 14.90,
      periodDays: 30,
    ),
    feature: BillingProduct(
      code: 'job_feature',
      name: 'Destaque de projeto',
      price: 9.90,
      periodDays: 7,
    ),
    settings: PlatformSettings(),
  );
}
