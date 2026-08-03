import '../entities/chat_message.dart';
import '../entities/conversation.dart';

abstract class ChatRepository {
  Future<List<Conversation>> getConversations();
  Future<Conversation?> getConversationById(String id);
  Stream<List<ChatMessage>> getMessagesStream(String conversationId);
  Future<void> sendMessage(String conversationId, String content, {MessageType type});
  Future<void> updateMilestoneStatus(String conversationId, String milestoneId, MilestoneStatus status);
}
