/// Resultado de uma cobrança criada pelas Edge Functions do Asaas.
library;

/// QR Code Pix para pagar sem sair do app.
class PixCharge {
  /// PNG em base64, gerado pelo Asaas.
  final String imageBase64;

  /// Código "copia e cola".
  final String payload;
  final DateTime? expiresAt;

  const PixCharge({
    required this.imageBase64,
    required this.payload,
    this.expiresAt,
  });

  factory PixCharge.fromJson(Map<String, dynamic> json) => PixCharge(
    imageBase64: json['image_base64'] as String? ?? '',
    payload: json['payload'] as String? ?? '',
    expiresAt: DateTime.tryParse('${json['expires_at']}'),
  );
}

class CheckoutResult {
  /// Cupom de 100%: o produto foi liberado sem cobrança.
  final bool granted;
  final double? amount;
  final String? paymentId;
  final PixCharge? pix;

  /// Página segura do Asaas (cartão) ou fatura completa.
  final Uri? invoiceUrl;

  const CheckoutResult({
    this.granted = false,
    this.amount,
    this.paymentId,
    this.pix,
    this.invoiceUrl,
  });

  factory CheckoutResult.fromPaymentResponse(
    Map<String, dynamic> data, {
    required bool requiresPix,
  }) {
    final result = CheckoutResult.fromJson(data);
    if (!result.granted &&
        requiresPix &&
        (result.pix == null || result.pix!.payload.isEmpty)) {
      throw Exception(
        'Pix ainda indisponível. Retome esta cobrança em instantes.',
      );
    }
    if (!result.granted && result.pix == null && result.invoiceUrl == null) {
      throw Exception('Pagamento indisponível. Tente novamente.');
    }
    return result;
  }

  factory CheckoutResult.fromJson(Map<String, dynamic> json) => CheckoutResult(
    granted: json['granted'] == true,
    amount: (json['amount'] as num?)?.toDouble(),
    paymentId: json['payment_id'] as String?,
    pix: json['pix'] is Map
        ? PixCharge.fromJson(Map<String, dynamic>.from(json['pix'] as Map))
        : null,
    invoiceUrl: (json['invoice_url'] as String?)?.isNotEmpty == true
        ? Uri.parse(json['invoice_url'] as String)
        : null,
  );
}

/// Preço com cupom aplicado (função `quote_price` do banco).
class PriceQuote {
  final double price;
  final double finalPrice;
  final double discount;
  final String? code;
  final String? description;

  const PriceQuote({
    required this.price,
    required this.finalPrice,
    this.discount = 0,
    this.code,
    this.description,
  });

  bool get isFree => finalPrice <= 0;

  factory PriceQuote.fromJson(Map<String, dynamic> json) => PriceQuote(
    price: (json['price'] as num?)?.toDouble() ?? 0,
    finalPrice: (json['final_price'] as num?)?.toDouble() ?? 0,
    discount: (json['discount'] as num?)?.toDouble() ?? 0,
    code: json['code'] as String?,
    description: json['description'] as String?,
  );
}
