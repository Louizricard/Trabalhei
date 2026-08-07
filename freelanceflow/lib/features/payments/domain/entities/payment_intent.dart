class PaymentIntentResult {
  final bool success;
  final String? transactionId;
  final String? gatewayRef;
  final String status;
  final String? statusDetail;
  final String? qrCode;
  final String? qrCodeBase64;
  final String? ticketUrl;
  final DateTime? expiresAt;
  final String? errorMessage;

  const PaymentIntentResult({
    required this.success,
    this.transactionId,
    this.gatewayRef,
    required this.status,
    this.statusDetail,
    this.qrCode,
    this.qrCodeBase64,
    this.ticketUrl,
    this.expiresAt,
    this.errorMessage,
  });

  factory PaymentIntentResult.fromJson(Map<String, dynamic> json) {
    return PaymentIntentResult(
      success:
          json['success'] as bool? ??
          (json['status'] == 'approved' || json['status'] == 'pending'),
      transactionId: json['transaction_id'] as String?,
      gatewayRef: json['gateway_ref']?.toString(),
      status: json['status'] as String? ?? 'pending',
      statusDetail: json['status_detail'] as String?,
      qrCode: json['qr_code'] as String?,
      qrCodeBase64: json['qr_code_base64'] as String?,
      ticketUrl: json['ticket_url'] as String?,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      errorMessage: json['error'] as String?,
    );
  }

  factory PaymentIntentResult.error(String message) {
    return PaymentIntentResult(
      success: false,
      status: 'error',
      errorMessage: message,
    );
  }

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending' || status == 'in_process';
}

class CardPaymentData {
  final String cardNumber;
  final String cardholderName;
  final String expirationMonth;
  final String expirationYear;
  final String securityCode;
  final String cpf;
  final int installments;
  final String? paymentMethodId; // 'master', 'visa', 'elo', etc.

  const CardPaymentData({
    required this.cardNumber,
    required this.cardholderName,
    required this.expirationMonth,
    required this.expirationYear,
    required this.securityCode,
    required this.cpf,
    this.installments = 1,
    this.paymentMethodId,
  });

  String get cleanCardNumber => cardNumber.replaceAll(RegExp(r'\D'), '');
  String get cleanCpf => cpf.replaceAll(RegExp(r'\D'), '');

  String detectBrand() {
    final num = cleanCardNumber;
    if (RegExp(
      r'^(4011|4312|4389|4514|4576|5041|5066|5067|509|6277|6362|6363|650|6516|6550)',
    ).hasMatch(num))
      return 'elo';
    if (RegExp(r'^(606282|3841)').hasMatch(num)) return 'hipercard';
    if (RegExp(r'^(34|37)').hasMatch(num)) return 'amex';
    if (RegExp(r'^(5[1-5]|222[1-9]|22[3-9]|2[3-6]|27[0-1]|2720)').hasMatch(num))
      return 'master';
    if (RegExp(r'^(6011|65|64[4-9])').hasMatch(num)) return 'discover';
    if (RegExp(r'^(301|305|36|38)').hasMatch(num)) return 'diners';
    if (num.startsWith('4')) return 'visa';
    return paymentMethodId ?? 'visa';
  }
}
