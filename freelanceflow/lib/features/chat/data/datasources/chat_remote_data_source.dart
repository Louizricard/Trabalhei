import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/utils/realtime_retry.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';

class ChatRemoteDataSource {
  static const _conversationSelect = '''
    id,
    job_id,
    client_id,
    freelancer_id,
    contract_id,
    last_message_at,
    last_message_preview,
    jobs (title),
    client:profiles!client_id (id, full_name, avatar_url),
    freelancer:profiles!freelancer_id (id, full_name, avatar_url),
    contracts:contract_id (
      id,
      status,
      milestones (id, contract_id, title, description, amount, status, sort_order, due_date, deliverable_notes, deliverable_attachments, submitted_at, revision_count)
    )
  ''';

  final SupabaseClient _supabase;

  ChatRemoteDataSource(this._supabase);

  SupabaseClient get supabase => _supabase;

  /// Quantidade de mensagens não lidas (enviadas pela outra parte) por conversa.
  Future<Map<String, int>> _unreadCounts(String userId) async {
    final rows = await _supabase
        .from('messages')
        .select('conversation_id')
        .eq('is_read', false)
        .neq('sender_id', userId);
    final counts = <String, int>{};
    for (final row in rows as List) {
      final id = (row as Map)['conversation_id'] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  Future<List<Conversation>> getConversations() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return [];

    // RLS já restringe às conversas do usuário.
    final response = await _supabase
        .from('conversations')
        .select(_conversationSelect)
        .order('last_message_at', ascending: false);
    final unread = await _unreadCounts(currentUserId);

    return (response as List)
        .map(
          (json) => _mapToConversation(
            json as Map<String, dynamic>,
            currentUserId,
            unread[(json)['id']] ?? 0,
          ),
        )
        .toList();
  }

  Future<Conversation?> getConversationById(String id) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return null;

    final response = await _supabase
        .from('conversations')
        .select(_conversationSelect)
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return _mapToConversation(response, currentUserId, 0);
  }

  /// Encontra (ou cria, no servidor) a conversa entre cliente e freelancer.
  Future<Conversation> getOrCreateConversation({
    required String jobId,
    required String freelancerId,
    required String clientId,
    String? contractId,
  }) async {
    final hasJob = jobId.isNotEmpty;
    final id = await _supabase.rpc(
      'get_or_create_conversation',
      params: {
        'p_client_id': clientId,
        'p_freelancer_id': freelancerId,
        'p_job_id': hasJob ? jobId : null,
      },
    );
    final conv = await getConversationById(id as String);
    if (conv == null) throw Exception('Não foi possível abrir a conversa.');
    return conv;
  }

  Stream<List<ChatMessage>> getMessagesStream(String conversationId) {
    return resilientRealtimeStream(
      _supabase,
      () => _supabase
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true)
          .map(
            (list) => list.map((json) => ChatMessage.fromJson(json)).toList(),
          ),
    );
  }

  Future<void> markConversationRead(String conversationId) async {
    await _supabase.rpc(
      'mark_conversation_read',
      params: {'p_conversation_id': conversationId},
    );
  }

  Future<void> sendMessage(
    String conversationId,
    String content, {
    MessageType type = MessageType.text,
    String? attachmentUrl,
    String? attachmentName,
    int? attachmentSize,
    String? attachmentMime,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');

    // Mensagens de sistema são geradas exclusivamente pelo servidor.
    final String dbType = switch (type) {
      MessageType.image => 'image',
      MessageType.file => 'file',
      MessageType.document => 'document',
      _ => 'text',
    };

    await _supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': user.id,
      'content': content.trim(),
      'message_type': dbType,
      'attachment_url': ?attachmentUrl,
      'attachment_name': ?attachmentName,
      'attachment_size': ?attachmentSize,
      'attachment_mime': ?attachmentMime,
    });
  }

  Future<void> sendAttachmentMessage({
    required String conversationId,
    required AppAttachment attachment,
    String? caption,
  }) async {
    final isImg = attachment.mimeType.startsWith('image/');
    final text = (caption != null && caption.trim().isNotEmpty)
        ? caption.trim()
        : attachment.name;

    await sendMessage(
      conversationId,
      text,
      type: isImg ? MessageType.image : MessageType.file,
      attachmentUrl: attachment.url,
      attachmentName: attachment.name,
      attachmentSize: attachment.size,
      attachmentMime: attachment.mimeType,
    );
  }

  /// Cliente aprova a entrega do marco. Se for o último, o servidor conclui o contrato.
  Future<void> approveMilestone(String milestoneId) async {
    await _supabase.rpc(
      'approve_milestone',
      params: {'p_milestone_id': milestoneId},
    );
  }

  Future<void> submitMilestoneDeliverable({
    required String milestoneId,
    required String notes,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    await _supabase.rpc(
      'submit_deliverable',
      params: {
        'p_milestone_id': milestoneId,
        'p_notes': notes,
        'p_attachments': attachments,
      },
    );
  }

  Future<void> requestMilestoneRevision({
    required String milestoneId,
    required String comment,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    await _supabase.rpc(
      'request_revision',
      params: {
        'p_milestone_id': milestoneId,
        'p_comment': comment,
        'p_attachments': attachments,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getMilestoneRevisions(
    String milestoneId,
  ) async {
    final response = await _supabase
        .from('milestone_revisions')
        .select()
        .eq('milestone_id', milestoneId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response as List);
  }

  Conversation _mapToConversation(
    Map<String, dynamic> json,
    String currentUserId,
    int unread,
  ) {
    final clientId = json['client_id'] as String;
    final freelancerId = json['freelancer_id'] as String;
    final iAmClient = clientId == currentUserId;

    final other =
        (iAmClient ? json['freelancer'] : json['client'])
            as Map<String, dynamic>?;

    final jobTitle = json['jobs'] is Map
        ? (json['jobs']['title'] as String? ?? 'Conversa direta')
        : 'Conversa direta';

    final milestones = <ContractMilestone>[];
    final contract = json['contracts'];
    if (contract is Map && contract['milestones'] is List) {
      final raw = (contract['milestones'] as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      raw.sort(
        (a, b) => ((a['sort_order'] as num?) ?? 0).compareTo(
          (b['sort_order'] as num?) ?? 0,
        ),
      );
      milestones.addAll(raw.map(ContractMilestone.fromJson));
    }

    return Conversation(
      id: json['id'] as String,
      contractId: json['contract_id'] as String?,
      contractStatus: contract is Map ? contract['status'] as String? : null,
      clientId: clientId,
      freelancerId: freelancerId,
      jobTitle: jobTitle,
      otherParticipantId: iAmClient ? freelancerId : clientId,
      otherParticipantName: other?['full_name'] as String? ?? 'Usuário',
      otherParticipantAvatar: other?['avatar_url'] as String?,
      lastMessage:
          json['last_message_preview'] as String? ?? 'Nenhuma mensagem ainda',
      lastMessageAt:
          DateTime.tryParse(json['last_message_at'] as String? ?? '') ??
          DateTime.now(),
      unreadCount: unread,
      milestones: milestones,
    );
  }
}
