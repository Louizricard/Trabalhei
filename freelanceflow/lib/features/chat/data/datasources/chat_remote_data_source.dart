import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/storage_service.dart';
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
          job_id,
          client_id,
          freelancer_id,
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
            milestones (id, contract_id, title, description, amount, status, due_date, deliverable_notes, deliverable_attachments, submitted_at, revision_count)
          ),
          messages (content, is_read, sender_id, created_at)
        ''')
        .or(
          'participant_a.eq.$currentUserId,participant_b.eq.$currentUserId,client_id.eq.$currentUserId,freelancer_id.eq.$currentUserId',
        )
        .order('last_message_at', ascending: false);

    final List<dynamic> data = response as List<dynamic>;
    return data
        .map(
          (json) =>
              _mapToConversation(json as Map<String, dynamic>, currentUserId),
        )
        .toList();
  }

  Future<Conversation?> getConversationById(String id) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return null;

    final response = await _supabase
        .from('conversations')
        .select('''
          id,
          job_id,
          client_id,
          freelancer_id,
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
            milestones (id, contract_id, title, description, amount, status, due_date, deliverable_notes, deliverable_attachments, submitted_at, revision_count)
          ),
          messages (content, is_read, sender_id, created_at)
        ''')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return _mapToConversation(response, currentUserId);
  }

  Future<Conversation> getOrCreateConversation({
    required String jobId,
    required String freelancerId,
    required String clientId,
    String? contractId,
  }) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Usuário não autenticado.');

    final hasValidJobId =
        jobId.isNotEmpty && jobId != '00000000-0000-0000-0000-000000000000';

    // 1. Verificar se já existe conversa entre estes participantes
    final selectBuilder = _supabase.from('conversations').select('''
          id,
          job_id,
          client_id,
          freelancer_id,
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
            milestones (id, contract_id, title, description, amount, status, due_date, deliverable_notes, deliverable_attachments, submitted_at, revision_count)
          ),
          messages (content, is_read, sender_id, created_at)
        ''');

    dynamic response;
    if (hasValidJobId) {
      response = await selectBuilder.eq('job_id', jobId);
    } else {
      response = await selectBuilder.or(
        'and(participant_a.eq.$clientId,participant_b.eq.$freelancerId),and(participant_a.eq.$freelancerId,participant_b.eq.$clientId),and(client_id.eq.$clientId,freelancer_id.eq.$freelancerId),and(client_id.eq.$freelancerId,freelancer_id.eq.$clientId)',
      );
    }

    final List<dynamic> existing = (response as List<dynamic>?) ?? [];
    for (final item in existing) {
      final map = item as Map<String, dynamic>;
      final partA = (map['participant_a'] ?? map['client_id']) as String?;
      final partB = (map['participant_b'] ?? map['freelancer_id']) as String?;
      final match =
          (partA == clientId && partB == freelancerId) ||
          (partA == freelancerId && partB == clientId);
      if (match) {
        if (contractId != null && map['contract_id'] == null) {
          await _supabase
              .from('conversations')
              .update({'contract_id': contractId})
              .eq('id', map['id'] as String);
          return (await getConversationById(map['id'] as String)) ??
              _mapToConversation(map, currentUserId);
        }
        return _mapToConversation(map, currentUserId);
      }
    }

    // 2. Criar nova conversa
    final insertPayload = <String, dynamic>{
      if (hasValidJobId) 'job_id': jobId,
      'client_id': clientId,
      'freelancer_id': freelancerId,
      'participant_a': clientId,
      'participant_b': freelancerId,
      'last_message_at': DateTime.now().toIso8601String(),
    };
    if (contractId != null) {
      insertPayload['contract_id'] = contractId;
    }

    final inserted = await _supabase
        .from('conversations')
        .insert(insertPayload)
        .select('id')
        .single();
    final newId = inserted['id'] as String;

    final conv = await getConversationById(newId);
    if (conv != null) return conv;

    return Conversation(
      id: newId,
      contractId: contractId,
      jobTitle: 'Projeto',
      otherParticipantId: currentUserId == clientId ? freelancerId : clientId,
      otherParticipantName: 'Usuário',
      otherParticipantAvatar: null,
      lastMessage: 'Conversa iniciada',
      lastMessageAt: DateTime.now(),
      unreadCount: 0,
      milestones: [],
    );
  }

  Stream<List<ChatMessage>> getMessagesStream(String conversationId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((list) => list.map((json) => ChatMessage.fromJson(json)).toList());
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

    String dbType = 'text';
    if (type == MessageType.systemEvent) dbType = 'system_event';
    if (type == MessageType.milestoneUpdate) dbType = 'milestone_update';
    if (type == MessageType.image) dbType = 'image';
    if (type == MessageType.file || type == MessageType.document)
      dbType = 'file';

    final payload = <String, dynamic>{
      'conversation_id': conversationId,
      'sender_id': user.id,
      'content': content.trim(),
      'message_type': dbType,
      'is_read': false,
    };

    if (attachmentUrl != null) payload['attachment_url'] = attachmentUrl;
    if (attachmentName != null) payload['attachment_name'] = attachmentName;
    if (attachmentSize != null) payload['attachment_size'] = attachmentSize;
    if (attachmentMime != null) payload['attachment_mime'] = attachmentMime;

    await _supabase.from('messages').insert(payload);

    await _supabase
        .from('conversations')
        .update({'last_message_at': DateTime.now().toIso8601String()})
        .eq('id', conversationId);
  }

  Future<void> sendAttachmentMessage({
    required String conversationId,
    required AppAttachment attachment,
    String? caption,
  }) async {
    final isImg = attachment.mimeType.startsWith('image/');
    final msgType = isImg ? MessageType.image : MessageType.file;
    final text = (caption != null && caption.trim().isNotEmpty)
        ? caption.trim()
        : attachment.name;

    await sendMessage(
      conversationId,
      text,
      type: msgType,
      attachmentUrl: attachment.url,
      attachmentName: attachment.name,
      attachmentSize: attachment.size,
      attachmentMime: attachment.mimeType,
    );
  }

  Future<void> updateMilestoneStatus(
    String conversationId,
    String milestoneId,
    MilestoneStatus status,
  ) async {
    String dbStatus = 'pending';
    if (status == MilestoneStatus.fundedInEscrow) dbStatus = 'funded_in_escrow';
    if (status == MilestoneStatus.submitted) dbStatus = 'submitted';
    if (status == MilestoneStatus.inRevision) dbStatus = 'in_revision';
    if (status == MilestoneStatus.approvedAndReleased)
      dbStatus = 'approved_and_released';
    if (status == MilestoneStatus.disputed) dbStatus = 'disputed';

    if (status == MilestoneStatus.approvedAndReleased) {
      try {
        await _supabase.rpc(
          'release_escrow_milestone',
          params: {'p_milestone_id': milestoneId},
        );
      } catch (_) {
        await _supabase
            .from('milestones')
            .update({'status': 'approved_and_released'})
            .eq('id', milestoneId);
      }
    } else {
      await _supabase
          .from('milestones')
          .update({'status': dbStatus})
          .eq('id', milestoneId);
    }

    String statusText;
    if (status == MilestoneStatus.submitted) {
      statusText =
          '📦 O marco de entrega foi enviado pelo freelancer para aprovação.';
    } else if (status == MilestoneStatus.inRevision) {
      statusText = '🔄 O cliente solicitou revisão na entrega do marco.';
    } else if (status == MilestoneStatus.approvedAndReleased) {
      statusText =
          '🎉 Marco aprovado pelo cliente! O pagamento foi liberado do Escrow para a carteira.';
    } else {
      statusText = '⚠️ Status do Marco atualizado para: ${status.name}';
    }

    await sendMessage(
      conversationId,
      statusText,
      type: MessageType.systemEvent,
    );
  }

  Future<void> submitMilestoneDeliverable({
    required String conversationId,
    required String milestoneId,
    required String notes,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    await _supabase
        .from('milestones')
        .update({
          'status': 'submitted',
          'deliverable_notes': notes.trim(),
          'deliverable_attachments': attachments,
          'submitted_at': DateTime.now().toIso8601String(),
        })
        .eq('id', milestoneId);

    final text =
        '📦 Entrega enviada pelo Freelancer:\n\n"$notes"${attachments.isNotEmpty ? '\n(${attachments.length} arquivo(s) anexado(s))' : ''}';
    await sendMessage(conversationId, text, type: MessageType.systemEvent);
  }

  Future<void> requestMilestoneRevision({
    required String conversationId,
    required String milestoneId,
    required String contractId,
    required String comment,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');

    // 1. Criar registro de revisão
    await _supabase.from('milestone_revisions').insert({
      'milestone_id': milestoneId,
      'contract_id': contractId,
      'requested_by': user.id,
      'comment': comment.trim(),
      'attachments': attachments,
      'status': 'open',
    });

    // 2. Incrementar contagem e atualizar status do marco
    await _supabase
        .from('milestones')
        .update({'status': 'in_revision'})
        .eq('id', milestoneId);

    // 3. Notificar no chat
    final text =
        '🔄 Revisão Solicitada pelo Cliente:\n\n"$comment"${attachments.isNotEmpty ? '\n(${attachments.length} anexo(s))' : ''}';
    await sendMessage(conversationId, text, type: MessageType.systemEvent);
  }

  Future<List<Map<String, dynamic>>> getMilestoneRevisions(
    String milestoneId,
  ) async {
    try {
      final response = await _supabase
          .from('milestone_revisions')
          .select('*')
          .eq('milestone_id', milestoneId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (_) {
      return [];
    }
  }

  Conversation _mapToConversation(
    Map<String, dynamic> json,
    String currentUserId,
  ) {
    final clientId = (json['client_id'] ?? json['participant_a']) as String?;
    final freelancerId =
        (json['freelancer_id'] ?? json['participant_b']) as String?;
    final partAId = (json['participant_a'] ?? clientId) as String?;
    final partBId = (json['participant_b'] ?? freelancerId) as String?;
    final isPartA = partAId == currentUserId;

    final otherProfile = isPartA
        ? json['participant_b_profile'] as Map<String, dynamic>?
        : json['participant_a_profile'] as Map<String, dynamic>?;

    final otherId = isPartA ? (partBId ?? '') : (partAId ?? '');
    final otherName = otherProfile?['full_name'] as String? ?? 'Usuário';
    final otherAvatar = otherProfile?['avatar_url'] as String?;

    final jobTitle = json['jobs'] is Map
        ? (json['jobs']['title'] as String? ?? 'Projeto')
        : 'Projeto';

    final messages = (json['messages'] as List<dynamic>?) ?? [];
    String lastMsg = 'Nenhuma mensagem ainda';
    DateTime lastMsgTime =
        DateTime.tryParse(json['last_message_at'] as String? ?? '') ??
        DateTime.now();

    if (messages.isNotEmpty) {
      final latest = messages.last as Map<String, dynamic>;
      lastMsg = latest['content'] as String? ?? lastMsg;
    }

    int unread = 0;
    for (final m in messages) {
      if (m is Map<String, dynamic> &&
          m['is_read'] == false &&
          m['sender_id'] != currentUserId) {
        unread++;
      }
    }

    final List<ContractMilestone> milestones = [];
    if (json['contracts'] is Map && (json['contracts']['milestones'] is List)) {
      for (final m in json['contracts']['milestones'] as List) {
        if (m is Map) {
          milestones.add(
            ContractMilestone.fromJson(Map<String, dynamic>.from(m)),
          );
        }
      }
    }

    return Conversation(
      id: json['id'] as String,
      contractId: json['contract_id'] as String?,
      clientId: clientId,
      freelancerId: freelancerId,
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
