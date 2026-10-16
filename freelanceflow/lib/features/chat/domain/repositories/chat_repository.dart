import '../../../../core/services/storage_service.dart';
import '../entities/chat_message.dart';
import '../entities/conversation.dart';

abstract class ChatRepository {
  Future<List<Conversation>> getConversations();
  Future<Conversation?> getConversationById(String id);
  Future<Conversation> getOrCreateConversation({
    required String jobId,
    required String freelancerId,
    required String clientId,
    String? contractId,
  });
  Stream<List<ChatMessage>> getMessagesStream(String conversationId);
  Future<void> sendMessage(
    String conversationId,
    String content, {
    MessageType type,
    String? attachmentUrl,
    String? attachmentName,
    int? attachmentSize,
    String? attachmentMime,
  });
  Future<void> sendAttachmentMessage({
    required String conversationId,
    required AppAttachment attachment,
    String? caption,
  });
  Future<void> markConversationRead(String conversationId);
  Future<void> approveMilestone(String milestoneId);
  Future<void> submitMilestoneDeliverable({
    required String milestoneId,
    required String notes,
    List<Map<String, dynamic>> attachments = const [],
  });
  Future<void> requestMilestoneRevision({
    required String milestoneId,
    required String comment,
    List<Map<String, dynamic>> attachments = const [],
  });
  Future<List<Map<String, dynamic>>> getMilestoneRevisions(String milestoneId);
}
