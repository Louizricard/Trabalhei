/// Estado de um marco de entrega. Não há custódia de valores: o `amount` é
/// apenas o valor acordado entre as partes, pago fora da plataforma.
enum MilestoneStatus { pending, submitted, inRevision, approved }

class ContractMilestone {
  final String id;
  final String contractId;
  final String title;
  final String description;
  final double amount;
  final MilestoneStatus status;
  final DateTime? dueDate;
  final String? deliverableNotes;
  final List<Map<String, dynamic>> deliverableAttachments;
  final DateTime? submittedAt;
  final int revisionCount;

  const ContractMilestone({
    required this.id,
    required this.contractId,
    required this.title,
    this.description = '',
    required this.amount,
    this.status = MilestoneStatus.pending,
    this.dueDate,
    this.deliverableNotes,
    this.deliverableAttachments = const [],
    this.submittedAt,
    this.revisionCount = 0,
  });

  factory ContractMilestone.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> parsedAttachments = [];
    if (json['deliverable_attachments'] is List) {
      parsedAttachments = (json['deliverable_attachments'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return ContractMilestone(
      id: json['id'] as String,
      contractId: json['contract_id'] as String? ?? '',
      title: json['title'] as String? ?? 'Marco',
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: _parseStatus(json['status'] as String?),
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'] as String)
          : null,
      deliverableNotes: json['deliverable_notes'] as String?,
      deliverableAttachments: parsedAttachments,
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'] as String)
          : null,
      revisionCount: (json['revision_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'contract_id': contractId,
    'title': title,
    'description': description,
    'amount': amount,
    'status': _statusToDb(status),
    'deliverable_notes': deliverableNotes,
    'deliverable_attachments': deliverableAttachments,
    'submitted_at': submittedAt?.toIso8601String(),
    'revision_count': revisionCount,
  };

  static String _statusToDb(MilestoneStatus s) {
    switch (s) {
      case MilestoneStatus.submitted:
        return 'submitted';
      case MilestoneStatus.inRevision:
        return 'in_revision';
      case MilestoneStatus.approved:
        return 'approved';
      case MilestoneStatus.pending:
        return 'pending';
    }
  }

  ContractMilestone copyWith({
    MilestoneStatus? status,
    String? deliverableNotes,
    List<Map<String, dynamic>>? deliverableAttachments,
    DateTime? submittedAt,
    int? revisionCount,
  }) {
    return ContractMilestone(
      id: id,
      contractId: contractId,
      title: title,
      description: description,
      amount: amount,
      status: status ?? this.status,
      dueDate: dueDate,
      deliverableNotes: deliverableNotes ?? this.deliverableNotes,
      deliverableAttachments:
          deliverableAttachments ?? this.deliverableAttachments,
      submittedAt: submittedAt ?? this.submittedAt,
      revisionCount: revisionCount ?? this.revisionCount,
    );
  }

  static MilestoneStatus _parseStatus(String? s) {
    switch (s) {
      case 'submitted':
        return MilestoneStatus.submitted;
      case 'in_revision':
        return MilestoneStatus.inRevision;
      case 'approved':
        return MilestoneStatus.approved;
      default:
        return MilestoneStatus.pending;
    }
  }
}

class Conversation {
  final String id;
  final String? contractId;
  final String? clientId;
  final String? freelancerId;
  final String jobTitle;
  final String otherParticipantId;
  final String otherParticipantName;
  final String? otherParticipantAvatar;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final List<ContractMilestone> milestones;

  /// Status do contrato vinculado (`active`, `completed`, `cancelled`), se houver.
  final String? contractStatus;

  const Conversation({
    required this.id,
    this.contractId,
    this.contractStatus,
    this.clientId,
    this.freelancerId,
    required this.jobTitle,
    required this.otherParticipantId,
    required this.otherParticipantName,
    this.otherParticipantAvatar,
    required this.lastMessage,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.milestones = const [],
  });

  /// Avaliações só são liberadas depois que o contrato é concluído.
  bool get isContractCompleted =>
      contractId != null && contractStatus == 'completed';
}
