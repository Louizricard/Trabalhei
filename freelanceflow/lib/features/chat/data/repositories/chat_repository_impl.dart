import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_data_source.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource _remoteDataSource;

  ChatRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<Conversation>> getConversations() {
    return _remoteDataSource.getConversations();
  }

  @override
  Future<Conversation?> getConversationById(String id) {
    return _remoteDataSource.getConversationById(id);
  }

  @override
  Stream<List<ChatMessage>> getMessagesStream(String conversationId) {
    return _remoteDataSource.getMessagesStream(conversationId);
  }

  @override
  Future<void> sendMessage(String conversationId, String content, {MessageType type = MessageType.text}) {
    return _remoteDataSource.sendMessage(conversationId, content, type: type);
  }

  @override
  Future<void> updateMilestoneStatus(String conversationId, String milestoneId, MilestoneStatus status) {
    return _remoteDataSource.updateMilestoneStatus(conversationId, milestoneId, status);
  }
}
