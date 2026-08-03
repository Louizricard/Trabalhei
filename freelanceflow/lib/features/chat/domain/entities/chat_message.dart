enum MessageType { text, systemEvent, milestoneUpdate }

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String? attachmentUrl;
  final MessageType messageType;
  final bool isRead;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.attachmentUrl,
    this.messageType = MessageType.text,
    this.isRead = false,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      attachmentUrl: json['attachment_url'] as String?,
      messageType: _parseType(json['message_type'] as String?),
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'attachment_url': attachmentUrl,
      'message_type': messageType.name,
      'is_read': isRead,
    };
  }

  static MessageType _parseType(String? type) {
    switch (type) {
      case 'system_event':
        return MessageType.systemEvent;
      case 'milestone_update':
        return MessageType.milestoneUpdate;
      default:
        return MessageType.text;
    }
  }
}
