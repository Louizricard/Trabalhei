enum TransactionType { deposit, escrowHold, escrowRelease, payoutPix, platformFee }
enum TransactionStatus { pending, completed, failed, refunded }

class WalletTransaction {
  final String id;
  final String userId;
  final String? contractTitle;
  final TransactionType type;
  final double amount;
  final TransactionStatus status;
  final String? pixKey;
  final String? gatewayProvider;
  final String? gatewayRef;
  final String? gatewayStatus;
  final String? qrCode;
  final String? qrCodeBase64;
  final String? paymentMethod;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.userId,
    this.contractTitle,
    required this.type,
    required this.amount,
    this.status = TransactionStatus.completed,
    this.pixKey,
    this.gatewayProvider,
    this.gatewayRef,
    this.gatewayStatus,
    this.qrCode,
    this.qrCodeBase64,
    this.paymentMethod,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    String? title;
    if (json['contracts'] is Map) {
      final c = json['contracts'] as Map<String, dynamic>;
      if (c['jobs'] is Map) {
        title = c['jobs']['title'] as String?;
      }
    }

    return WalletTransaction(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      contractTitle: title ?? json['contract_title'] as String?,
      type: _parseType(json['type'] as String?),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: _parseStatus(json['status'] as String?),
      pixKey: json['pix_key'] as String?,
      gatewayProvider: json['gateway_provider'] as String?,
      gatewayRef: json['gateway_ref']?.toString(),
      gatewayStatus: json['gateway_status'] as String?,
      qrCode: json['qr_code'] as String?,
      qrCodeBase64: json['qr_code_base64'] as String?,
      paymentMethod: json['payment_method'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'type': _typeToDb(type),
        'amount': amount,
        'status': status.name,
        'pix_key': pixKey,
        'gateway_provider': gatewayProvider,
        'gateway_ref': gatewayRef,
        'gateway_status': gatewayStatus,
        'qr_code': qrCode,
        'qr_code_base64': qrCodeBase64,
        'payment_method': paymentMethod,
      };

  String get typeLabel {
    switch (type) {
      case TransactionType.deposit:
        return 'Depósito via Pix';
      case TransactionType.escrowHold:
        return 'Garantia Retida em Escrow';
      case TransactionType.escrowRelease:
        return 'Liberação de Marco';
      case TransactionType.payoutPix:
        return 'Saque Instantâneo Pix';
      case TransactionType.platformFee:
        return 'Taxa de Serviço';
    }
  }

  bool get isCredit => type == TransactionType.escrowRelease || type == TransactionType.deposit;

  static TransactionType _parseType(String? t) {
    switch (t) {
      case 'deposit':
        return TransactionType.deposit;
      case 'escrow_hold':
      case 'escrowHold':
        return TransactionType.escrowHold;
      case 'escrow_release':
      case 'escrowRelease':
        return TransactionType.escrowRelease;
      case 'payout_pix':
      case 'payoutPix':
        return TransactionType.payoutPix;
      case 'platform_fee':
      case 'platformFee':
        return TransactionType.platformFee;
      default:
        return TransactionType.deposit;
    }
  }

  static String _typeToDb(TransactionType t) {
    switch (t) {
      case TransactionType.deposit:
        return 'deposit';
      case TransactionType.escrowHold:
        return 'escrow_hold';
      case TransactionType.escrowRelease:
        return 'escrow_release';
      case TransactionType.payoutPix:
        return 'payout_pix';
      case TransactionType.platformFee:
        return 'platform_fee';
    }
  }

  static TransactionStatus _parseStatus(String? s) {
    switch (s) {
      case 'pending':
        return TransactionStatus.pending;
      case 'failed':
        return TransactionStatus.failed;
      case 'refunded':
        return TransactionStatus.refunded;
      default:
        return TransactionStatus.completed;
    }
  }
}
