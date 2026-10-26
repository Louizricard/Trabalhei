/// Dados do painel de administração (vêm das funções `admin_*` do banco).
library;

enum ReportTarget { job, profile }

enum ReportReason {
  spam('spam', 'Spam ou propaganda'),
  fraud('fraud', 'Golpe ou fraude'),
  offensive('offensive', 'Conteúdo ofensivo'),
  fake('fake', 'Informação falsa'),
  offPlatformPayment(
    'off_platform_payment',
    'Pedido de dados ou pagamento suspeito',
  ),
  other('other', 'Outro motivo');

  final String dbValue;
  final String label;
  const ReportReason(this.dbValue, this.label);

  static ReportReason fromDb(String? value) => ReportReason.values.firstWhere(
    (r) => r.dbValue == value,
    orElse: () => ReportReason.other,
  );
}

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v');
int _int(Object? v) => (v as num?)?.toInt() ?? 0;

class AdminOverview {
  final int users;
  final int suspended;
  final int openJobs;
  final int openReports;

  const AdminOverview({
    required this.users,
    required this.suspended,
    required this.openJobs,
    required this.openReports,
  });

  factory AdminOverview.fromJson(Map<String, dynamic> json) => AdminOverview(
    users: _int(json['users']),
    suspended: _int(json['suspended']),
    openJobs: _int(json['open_jobs']),
    openReports: _int(json['open_reports']),
  );
}

class AdminReport {
  final String id;
  final ReportTarget target;
  final String targetId;
  final String? targetLabel;
  final ReportReason reason;
  final String? details;
  final String status;
  final DateTime createdAt;
  final String? reporterName;
  final int reportsOnTarget;

  const AdminReport({
    required this.id,
    required this.target,
    required this.targetId,
    this.targetLabel,
    required this.reason,
    this.details,
    required this.status,
    required this.createdAt,
    this.reporterName,
    this.reportsOnTarget = 1,
  });

  factory AdminReport.fromJson(Map<String, dynamic> json) => AdminReport(
    id: json['id'] as String,
    target: json['target_type'] == 'job'
        ? ReportTarget.job
        : ReportTarget.profile,
    targetId: json['target_id'] as String,
    targetLabel: json['target_label'] as String?,
    reason: ReportReason.fromDb(json['reason'] as String?),
    details: json['details'] as String?,
    status: json['status'] as String? ?? 'open',
    createdAt: _date(json['created_at']) ?? DateTime.now(),
    reporterName: json['reporter_name'] as String?,
    reportsOnTarget: _int(json['reports_on_target']),
  );
}

class AdminUser {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final String plan;
  final DateTime createdAt;
  final DateTime? lastSignInAt;
  final DateTime? suspendedAt;
  final bool isAdmin;
  final int openReports;

  const AdminUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.plan,
    required this.createdAt,
    this.lastSignInAt,
    this.suspendedAt,
    this.isAdmin = false,
    this.openReports = 0,
  });

  bool get isSuspended => suspendedAt != null;

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    id: json['id'] as String,
    fullName: json['full_name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: json['role'] as String? ?? 'freelancer',
    plan: json['plan'] as String? ?? 'free',
    createdAt: _date(json['created_at']) ?? DateTime.now(),
    lastSignInAt: _date(json['last_sign_in_at']),
    suspendedAt: _date(json['suspended_at']),
    isAdmin: json['is_admin'] as bool? ?? false,
    openReports: _int(json['open_reports']),
  );
}

class AdminJob {
  final String id;
  final String title;
  final String status;
  final String category;
  final String clientId;
  final String? clientName;
  final DateTime createdAt;
  final int openReports;

  const AdminJob({
    required this.id,
    required this.title,
    required this.status,
    required this.category,
    required this.clientId,
    this.clientName,
    required this.createdAt,
    this.openReports = 0,
  });

  factory AdminJob.fromJson(Map<String, dynamic> json) => AdminJob(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    status: json['status'] as String? ?? 'open',
    category: json['category'] as String? ?? '',
    clientId: json['client_id'] as String? ?? '',
    clientName: json['client_name'] as String?,
    createdAt: _date(json['created_at']) ?? DateTime.now(),
    openReports: _int(json['open_reports']),
  );
}

/// Cupom de desconto (tabela coupons, lida pelo painel de admin).
class AdminCoupon {
  final String code;
  final String? description;
  final String product;
  final int? percentOff;
  final double? amountOff;
  final int? maxRedemptions;
  final int redemptions;
  final DateTime? validUntil;
  final bool active;

  const AdminCoupon({
    required this.code,
    this.description,
    required this.product,
    this.percentOff,
    this.amountOff,
    this.maxRedemptions,
    this.redemptions = 0,
    this.validUntil,
    this.active = true,
  });

  bool get isExpired =>
      validUntil != null && validUntil!.isBefore(DateTime.now());
  bool get isExhausted =>
      maxRedemptions != null && redemptions >= maxRedemptions!;

  factory AdminCoupon.fromJson(Map<String, dynamic> json) => AdminCoupon(
    code: json['code'] as String,
    description: json['description'] as String?,
    product: json['product'] as String? ?? 'any',
    percentOff: (json['percent_off'] as num?)?.toInt(),
    amountOff: (json['amount_off'] as num?)?.toDouble(),
    maxRedemptions: (json['max_redemptions'] as num?)?.toInt(),
    redemptions: _int(json['redemptions_count']),
    validUntil: _date(json['valid_until']),
    active: json['active'] as bool? ?? true,
  );
}
