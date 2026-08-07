import 'package:flutter/foundation.dart';

/// Enum representing all domain notification types
enum NotificationType {
  newMessage,
  proposalReceived,
  proposalAccepted,
  contractActive,
  milestoneSubmitted,
  milestoneInRevision,
  milestoneApproved,
  disputeOpened,
  paymentReceived,
  system;

  static NotificationType fromString(String? value) {
    switch (value) {
      case 'new_message':
        return NotificationType.newMessage;
      case 'proposal_received':
        return NotificationType.proposalReceived;
      case 'proposal_accepted':
        return NotificationType.proposalAccepted;
      case 'contract_active':
        return NotificationType.contractActive;
      case 'milestone_submitted':
        return NotificationType.milestoneSubmitted;
      case 'milestone_in_revision':
        return NotificationType.milestoneInRevision;
      case 'milestone_approved':
        return NotificationType.milestoneApproved;
      case 'dispute_opened':
        return NotificationType.disputeOpened;
      case 'payment_received':
        return NotificationType.paymentReceived;
      default:
        return NotificationType.system;
    }
  }

  String toDbString() {
    switch (this) {
      case NotificationType.newMessage:
        return 'new_message';
      case NotificationType.proposalReceived:
        return 'proposal_received';
      case NotificationType.proposalAccepted:
        return 'proposal_accepted';
      case NotificationType.contractActive:
        return 'contract_active';
      case NotificationType.milestoneSubmitted:
        return 'milestone_submitted';
      case NotificationType.milestoneInRevision:
        return 'milestone_in_revision';
      case NotificationType.milestoneApproved:
        return 'milestone_approved';
      case NotificationType.disputeOpened:
        return 'dispute_opened';
      case NotificationType.paymentReceived:
        return 'payment_received';
      case NotificationType.system:
        return 'system';
    }
  }
}

/// Pure Dart domain entity representing an In-App notification
@immutable
class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.data = const {},
    this.isRead = false,
    required this.createdAt,
  });

  /// Extracts deep link navigation route from metadata if available
  String? get targetRoute => data['route'] as String?;

  /// Extracts associated conversation ID
  String? get conversationId => data['conversation_id'] as String?;

  /// Extracts associated job ID
  String? get jobId => data['job_id'] as String?;

  /// Extracts associated contract ID
  String? get contractId => data['contract_id'] as String?;

  /// Extracts associated milestone ID
  String? get milestoneId => data['milestone_id'] as String?;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      type: NotificationType.fromString(json['type'] as String?),
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : {},
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type.toDbString(),
      'data': data,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    NotificationType? type,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          isRead == other.isRead;

  @override
  int get hashCode => id.hashCode ^ userId.hashCode ^ isRead.hashCode;
}
