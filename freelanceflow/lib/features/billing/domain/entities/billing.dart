enum BillingMethod {
  pix('PIX', 'Pix'),
  creditCard('CREDIT_CARD', 'Cartão de crédito');

  final String apiValue;
  final String label;
  const BillingMethod(this.apiValue, this.label);
}

enum SubscriptionStatus {
  pending,
  active,
  overdue,
  cancelled;

  static SubscriptionStatus parse(String? value) {
    switch (value) {
      case 'active':
        return SubscriptionStatus.active;
      case 'overdue':
        return SubscriptionStatus.overdue;
      case 'cancelled':
        return SubscriptionStatus.cancelled;
      default:
        return SubscriptionStatus.pending;
    }
  }
}

/// Assinatura Pro do usuário (somente leitura no app).
class Subscription {
  final String id;
  final SubscriptionStatus status;
  final BillingMethod method;
  final DateTime? currentPeriodEnd;
  final DateTime createdAt;

  const Subscription({
    required this.id,
    required this.status,
    required this.method,
    required this.createdAt,
    this.currentPeriodEnd,
  });

  /// Assinatura ainda em vigor (inclui pendente de pagamento ou em atraso).
  bool get isOpen =>
      status == SubscriptionStatus.pending ||
      status == SubscriptionStatus.active ||
      status == SubscriptionStatus.overdue;

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      status: SubscriptionStatus.parse(json['status'] as String?),
      method: json['billing_type'] == 'CREDIT_CARD'
          ? BillingMethod.creditCard
          : BillingMethod.pix,
      currentPeriodEnd: json['current_period_end'] != null
          ? DateTime.tryParse(json['current_period_end'] as String)
          : null,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
