import '../../../../core/services/storage_service.dart';
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
  Future<Conversation> getOrCreateConversation({
    required String jobId,
    required String freelancerId,
    required String clientId,
    String? contractId,
  }) {
    return _remoteDataSource.getOrCreateConversation(
      jobId: jobId,
      freelancerId: freelancerId,
      clientId: clientId,
      contractId: contractId,
    );
  }

  @override
  Stream<List<ChatMessage>> getMessagesStream(String conversationId) {
    return _remoteDataSource.getMessagesStream(conversationId);
  }

  @override
  Future<void> sendMessage(
    String conversationId,
    String content, {
    MessageType type = MessageType.text,
    String? attachmentUrl,
    String? attachmentName,
    int? attachmentSize,
    String? attachmentMime,
  }) {
    return _remoteDataSource.sendMessage(
      conversationId,
      content,
      type: type,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      attachmentSize: attachmentSize,
      attachmentMime: attachmentMime,
    );
  }

  @override
  Future<void> sendAttachmentMessage({
    required String conversationId,
    required AppAttachment attachment,
    String? caption,
  }) {
    return _remoteDataSource.sendAttachmentMessage(
      conversationId: conversationId,
      attachment: attachment,
      caption: caption,
    );
  }

  @override
  Future<void> updateMilestoneStatus(String conversationId, String milestoneId, MilestoneStatus status) {
    return _remoteDataSource.updateMilestoneStatus(conversationId, milestoneId, status);
  }

  @override
  Future<void> submitMilestoneDeliverable({
    required String conversationId,
    required String milestoneId,
    required String notes,
    List<Map<String, dynamic>> attachments = const [],
  }) {
    return _remoteDataSource.submitMilestoneDeliverable(
      conversationId: conversationId,
      milestoneId: milestoneId,
      notes: notes,
      attachments: attachments,
    );
  }

  @override
  Future<void> requestMilestoneRevision({
    required String conversationId,
    required String milestoneId,
    required String contractId,
    required String comment,
    List<Map<String, dynamic>> attachments = const [],
  }) {
    return _remoteDataSource.requestMilestoneRevision(
      conversationId: conversationId,
      milestoneId: milestoneId,
      contractId: contractId,
      comment: comment,
      attachments: attachments,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getMilestoneRevisions(String milestoneId) {
    return _remoteDataSource.getMilestoneRevisions(milestoneId);
  }
}
