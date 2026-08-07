enum MessageType { text, systemEvent, milestoneUpdate, image, file, document }

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String? attachmentUrl;
  final String? attachmentName;
  final int? attachmentSize;
  final String? attachmentMime;
  final MessageType messageType;
  final bool isRead;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentSize,
    this.attachmentMime,
    this.messageType = MessageType.text,
    this.isRead = false,
    required this.createdAt,
  });

  bool get isImage =>
      messageType == MessageType.image ||
      (attachmentMime != null && attachmentMime!.startsWith('image/')) ||
      (attachmentName != null &&
          RegExp(
            r'\.(png|jpe?g|webp|gif)$',
            caseSensitive: false,
          ).hasMatch(attachmentName!));

  String get formattedSize {
    if (attachmentSize == null || attachmentSize! <= 0) {
      return '';
    }
    if (attachmentSize! < 1024) {
      return '${attachmentSize!} B';
    }
    if (attachmentSize! < 1024 * 1024) {
      return '${(attachmentSize! / 1024).toStringAsFixed(1)} KB';
    }
    return '${(attachmentSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String? ?? '',
      attachmentUrl: json['attachment_url'] as String?,
      attachmentName: json['attachment_name'] as String?,
      attachmentSize: (json['attachment_size'] as num?)?.toInt(),
      attachmentMime: json['attachment_mime'] as String?,
      messageType: _parseType(json['message_type'] as String?),
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'attachment_url': attachmentUrl,
      'attachment_name': attachmentName,
      'attachment_size': attachmentSize,
      'attachment_mime': attachmentMime,
      'message_type': _typeToString(messageType),
      'is_read': isRead,
    };
  }

  static String _typeToString(MessageType type) {
    switch (type) {
      case MessageType.systemEvent:
        return 'system_event';
      case MessageType.milestoneUpdate:
        return 'milestone_update';
      case MessageType.image:
        return 'image';
      case MessageType.file:
      case MessageType.document:
        return 'file';
      case MessageType.text:
        return 'text';
    }
  }

  static MessageType _parseType(String? type) {
    switch (type) {
      case 'system_event':
        return MessageType.systemEvent;
      case 'milestone_update':
        return MessageType.milestoneUpdate;
      case 'image':
        return MessageType.image;
      case 'file':
        return MessageType.file;
      case 'document':
        return MessageType.document;
      default:
        return MessageType.text;
    }
  }
}
