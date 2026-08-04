import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';

class ChatRemoteDataSource {
  final SupabaseClient _supabase;

  ChatRemoteDataSource(this._supabase);

  SupabaseClient get supabase => _supabase;

  Future<List<Conversation>> getConversations() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return [];

    final response = await _supabase
        .from('conversations')
        .select('''
          id,
          contract_id,
          participant_a,
          participant_b,
          last_message_at,
          created_at,
          jobs (title),
          participant_a_profile:profiles!participant_a (id, full_name, avatar_url),
          participant_b_profile:profiles!participant_b (id, full_name, avatar_url),
          contracts:contract_id (
            id,
            milestones (id, contract_id, title, description, amount, status, due_date)
          ),
          messages (content, is_read, sender_id, created_at)
        ''')
        .or('participant_a.eq.$currentUserId,participant_b.eq.$currentUserId')
        .order('last_message_at', ascending: false);

    final List<dynamic> data = response as List<dynamic>;
    return data.map((json) => _mapToConversation(json as Map<String, dynamic>, currentUserId)).toList();
  }

  Future<Conversation?> getConversationById(String id) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return null;

    final response = await _supabase
        .from('conversations')
        .select('''
          id,
          contract_id,
          participant_a,
          participant_b,
          last_message_at,
          created_at,
          jobs (title),
          participant_a_profile:profiles!participant_a (id, full_name, avatar_url),
          participant_b_profile:profiles!participant_b (id, full_name, avatar_url),
          contracts:contract_id (
            id,
            milestones (id, contract_id, title, description, amount, status, due_date)
          ),
          messages (content, is_read, sender_id, created_at)
        ''')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return _mapToConversation(response, currentUserId);
  }

  Stream<List<ChatMessage>> getMessagesStream(String conversationId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((list) => list.map((json) => ChatMessage.fromJson(json)).toList());
  }

  Future<void> sendMessage(String conversationId, String content, {MessageType type = MessageType.text}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');

    String dbType = 'text';
    if (type == MessageType.systemEvent) dbType = 'system_event';
    if (type == MessageType.milestoneUpdate) dbType = 'milestone_update';

    await _supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': user.id,
      'content': content.trim(),
      'message_type': dbType,
      'is_read': false,
    });

    await _supabase.from('conversations').update({
      'last_message_at': DateTime.now().toIso8601String(),
    }).eq('id', conversationId);
  }

  Future<void> updateMilestoneStatus(String conversationId, String milestoneId, MilestoneStatus status) async {
    String dbStatus = 'pending';
    if (status == MilestoneStatus.fundedInEscrow) dbStatus = 'funded_in_escrow';
    if (status == MilestoneStatus.submitted) dbStatus = 'submitted';
    if (status == MilestoneStatus.approvedAndReleased) dbStatus = 'approved_and_released';
    if (status == MilestoneStatus.disputed) dbStatus = 'disputed';

    if (status == MilestoneStatus.approvedAndReleased) {
      try {
        await _supabase.rpc('release_escrow_milestone', params: {'p_milestone_id': milestoneId});
      } catch (_) {
        await _supabase.from('milestones').update({'status': 'approved_and_released'}).eq('id', milestoneId);
      }
    } else {
      await _supabase.from('milestones').update({'status': dbStatus}).eq('id', milestoneId);
    }

    String statusText;
    if (status == MilestoneStatus.submitted) {
      statusText = '📦 O marco de entrega foi enviado pelo freelancer para aprovação.';
    } else if (status == MilestoneStatus.approvedAndReleased) {
      statusText = '🎉 Marco aprovado pelo cliente! O pagamento foi liberado do Escrow para a carteira.';
    } else {
      statusText = '⚠️ Status do Marco atualizado para: ${status.name}';
    }

    await sendMessage(conversationId, statusText, type: MessageType.systemEvent);
  }

  Conversation _mapToConversation(Map<String, dynamic> json, String currentUserId) {
    final partAId = json['participant_a'] as String?;
    final isPartA = partAId == currentUserId;

    final otherProfile = isPartA
        ? json['participant_b_profile'] as Map<String, dynamic>?
        : json['participant_a_profile'] as Map<String, dynamic>?;

    final otherId = isPartA ? json['participant_b'] as String? ?? '' : json['participant_a'] as String? ?? '';
    final otherName = otherProfile?['full_name'] as String? ?? 'Usuário';
    final otherAvatar = otherProfile?['avatar_url'] as String?;

    final jobTitle = json['jobs'] is Map ? (json['jobs']['title'] as String? ?? 'Projeto') : 'Projeto';

    final messages = (json['messages'] as List<dynamic>?) ?? [];
    String lastMsg = 'Nenhuma mensagem ainda';
    DateTime lastMsgTime = DateTime.tryParse(json['last_message_at'] as String? ?? '') ?? DateTime.now();

    if (messages.isNotEmpty) {
      final latest = messages.last as Map<String, dynamic>;
      lastMsg = latest['content'] as String? ?? lastMsg;
    }

    int unread = 0;
    for (final m in messages) {
      if (m is Map<String, dynamic> && m['is_read'] == false && m['sender_id'] != currentUserId) {
        unread++;
      }
    }

    final List<ContractMilestone> milestones = [];
    if (json['contracts'] is Map && (json['contracts']['milestones'] is List)) {
      for (final m in json['contracts']['milestones'] as List) {
        if (m is Map<String, dynamic>) {
          milestones.add(ContractMilestone.fromJson(m));
        }
      }
    }

    return Conversation(
      id: json['id'] as String,
      contractId: json['contract_id'] as String?,
      jobTitle: jobTitle,
      otherParticipantId: otherId,
      otherParticipantName: otherName,
      otherParticipantAvatar: otherAvatar,
      lastMessage: lastMsg,
      lastMessageAt: lastMsgTime,
      unreadCount: unread,
      milestones: milestones,
    );
  }
}
