class MilestoneRevision {
  final String id;
  final String milestoneId;
  final String contractId;
  final String requestedBy;
  final String comment;
  final List<Map<String, dynamic>> attachments;
  final String status;
  final DateTime createdAt;

  const MilestoneRevision({
    required this.id,
    required this.milestoneId,
    required this.contractId,
    required this.requestedBy,
    required this.comment,
    this.attachments = const [],
    this.status = 'open',
    required this.createdAt,
  });

  factory MilestoneRevision.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> parsedAttachments = [];
    if (json['attachments'] is List) {
      parsedAttachments = (json['attachments'] as List)
          .whereType<Map<String, dynamic>>()
          .toList();
    }

    return MilestoneRevision(
      id: json['id'] as String,
      milestoneId: json['milestone_id'] as String,
      contractId: json['contract_id'] as String,
      requestedBy: json['requested_by'] as String,
      comment: json['comment'] as String? ?? '',
      attachments: parsedAttachments,
      status: json['status'] as String? ?? 'open',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'milestone_id': milestoneId,
      'contract_id': contractId,
      'requested_by': requestedBy,
      'comment': comment,
      'attachments': attachments,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
