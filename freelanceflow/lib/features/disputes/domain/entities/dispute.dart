enum DisputeReason {
  nonDelivery,
  poorQuality,
  projectAbandoned,
  scopeDisagreement,
  unresponsive,
  other,
}

enum DisputeStatus {
  opened,
  underReview,
  resolvedFreelancer,
  resolvedClient,
  resolvedSplit,
  cancelled,
}

class Dispute {
  final String id;
  final String contractId;
  final String? milestoneId;
  final String openedBy;
  final String reason;
  final String description;
  final List<Map<String, dynamic>> evidenceAttachments;
  final DisputeStatus status;
  final String? resolutionSummary;
  final double? refundClientAmount;
  final double? releaseFreelancerAmount;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const Dispute({
    required this.id,
    required this.contractId,
    this.milestoneId,
    required this.openedBy,
    required this.reason,
    required this.description,
    this.evidenceAttachments = const [],
    this.status = DisputeStatus.opened,
    this.resolutionSummary,
    this.refundClientAmount,
    this.releaseFreelancerAmount,
    required this.createdAt,
    this.resolvedAt,
  });

  factory Dispute.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> parsedEvidence = [];
    if (json['evidence_attachments'] is List) {
      parsedEvidence = (json['evidence_attachments'] as List)
          .whereType<Map<String, dynamic>>()
          .toList();
    }

    return Dispute(
      id: json['id'] as String,
      contractId: json['contract_id'] as String,
      milestoneId: json['milestone_id'] as String?,
      openedBy: json['opened_by'] as String,
      reason: json['reason'] as String? ?? 'Outro',
      description: json['description'] as String? ?? '',
      evidenceAttachments: parsedEvidence,
      status: _parseStatus(json['status'] as String?),
      resolutionSummary: json['resolution_summary'] as String?,
      refundClientAmount: (json['refund_client_amount'] as num?)?.toDouble(),
      releaseFreelancerAmount: (json['release_freelancer_amount'] as num?)?.toDouble(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now() : DateTime.now(),
      resolvedAt: json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contract_id': contractId,
      'milestone_id': milestoneId,
      'opened_by': openedBy,
      'reason': reason,
      'description': description,
      'evidence_attachments': evidenceAttachments,
      'status': _statusToString(status),
      'resolution_summary': resolutionSummary,
      'refund_client_amount': refundClientAmount,
      'release_freelancer_amount': releaseFreelancerAmount,
    };
  }

  static DisputeStatus _parseStatus(String? s) {
    switch (s) {
      case 'under_review':
        return DisputeStatus.underReview;
      case 'resolved_freelancer':
        return DisputeStatus.resolvedFreelancer;
      case 'resolved_client':
        return DisputeStatus.resolvedClient;
      case 'resolved_split':
        return DisputeStatus.resolvedSplit;
      case 'cancelled':
        return DisputeStatus.cancelled;
      default:
        return DisputeStatus.opened;
    }
  }

  static String _statusToString(DisputeStatus s) {
    switch (s) {
      case DisputeStatus.underReview:
        return 'under_review';
      case DisputeStatus.resolvedFreelancer:
        return 'resolved_freelancer';
      case DisputeStatus.resolvedClient:
        return 'resolved_client';
      case DisputeStatus.resolvedSplit:
        return 'resolved_split';
      case DisputeStatus.cancelled:
        return 'cancelled';
      case DisputeStatus.opened:
        return 'opened';
    }
  }

  String get statusLabel {
    switch (status) {
      case DisputeStatus.opened:
        return 'Disputa Aberta';
      case DisputeStatus.underReview:
        return 'Em Análise pela Mediação';
      case DisputeStatus.resolvedFreelancer:
        return 'Resolvida em Favor do Freelancer';
      case DisputeStatus.resolvedClient:
        return 'Resolvida em Favor do Cliente';
      case DisputeStatus.resolvedSplit:
        return 'Acordo / Divisão de Valores';
      case DisputeStatus.cancelled:
        return 'Cancelada';
    }
  }
}
