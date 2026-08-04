enum MilestoneStatus { pending, fundedInEscrow, submitted, approvedAndReleased, disputed }

class ContractMilestone {
  final String id;
  final String contractId;
  final String title;
  final String description;
  final double amount;
  final MilestoneStatus status;
  final DateTime? dueDate;

  const ContractMilestone({
    required this.id,
    required this.contractId,
    required this.title,
    this.description = '',
    required this.amount,
    this.status = MilestoneStatus.pending,
    this.dueDate,
  });

  factory ContractMilestone.fromJson(Map<String, dynamic> json) {
    return ContractMilestone(
      id: json['id'] as String,
      contractId: json['contract_id'] as String? ?? '',
      title: json['title'] as String? ?? 'Marco',
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: _parseStatus(json['status'] as String?),
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'contract_id': contractId,
        'title': title,
        'description': description,
        'amount': amount,
        'status': _statusToDb(status),
      };

  static String _statusToDb(MilestoneStatus s) {
    switch (s) {
      case MilestoneStatus.fundedInEscrow:
        return 'funded_in_escrow';
      case MilestoneStatus.submitted:
        return 'submitted';
      case MilestoneStatus.approvedAndReleased:
        return 'approved_and_released';
      case MilestoneStatus.disputed:
        return 'disputed';
      case MilestoneStatus.pending:
        return 'pending';
    }
  }

  ContractMilestone copyWith({MilestoneStatus? status}) {
    return ContractMilestone(
      id: id,
      contractId: contractId,
      title: title,
      description: description,
      amount: amount,
      status: status ?? this.status,
      dueDate: dueDate,
    );
  }

  static MilestoneStatus _parseStatus(String? s) {
    switch (s) {
      case 'funded_in_escrow':
      case 'fundedInEscrow':
        return MilestoneStatus.fundedInEscrow;
      case 'submitted':
        return MilestoneStatus.submitted;
      case 'approved_and_released':
      case 'approvedAndReleased':
        return MilestoneStatus.approvedAndReleased;
      case 'disputed':
        return MilestoneStatus.disputed;
      default:
        return MilestoneStatus.pending;
    }
  }
}

class Conversation {
  final String id;
  final String? contractId;
  final String jobTitle;
  final String otherParticipantId;
  final String otherParticipantName;
  final String? otherParticipantAvatar;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final List<ContractMilestone> milestones;

  const Conversation({
    required this.id,
    this.contractId,
    required this.jobTitle,
    required this.otherParticipantId,
    required this.otherParticipantName,
    this.otherParticipantAvatar,
    required this.lastMessage,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.milestones = const [],
  });
}
