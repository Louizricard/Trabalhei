import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/dispute.dart';

class DisputeRemoteDataSource {
  final SupabaseClient _supabase;

  DisputeRemoteDataSource(this._supabase);

  Future<Dispute> openDispute({
    required String contractId,
    String? milestoneId,
    required String reason,
    required String description,
    List<Map<String, dynamic>> evidenceAttachments = const [],
    String? conversationId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');

    // 1. Inserir disputa no banco
    final payload = <String, dynamic>{
      'contract_id': contractId,
      'opened_by': user.id,
      'reason': reason,
      'description': description.trim(),
      'evidence_attachments': evidenceAttachments,
      'status': 'opened',
    };
    if (milestoneId != null) {
      payload['milestone_id'] = milestoneId;
    }

    final res = await _supabase.from('disputes').insert(payload).select('*').single();

    // 2. Se houver milestoneId, atualizar o status do milestone para disputed
    if (milestoneId != null) {
      await _supabase.from('milestones').update({'status': 'disputed'}).eq('id', milestoneId);
    }

    // 3. Notificar no chat se conversationId estiver disponível
    if (conversationId != null) {
      await _supabase.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': user.id,
        'content': '⚖️ Uma Mediação / Disputa foi aberta para este projeto.\nMotivo: $reason\n\nNossa equipe de mediação avaliará o caso e entrará em contato.',
        'message_type': 'system_event',
        'is_read': false,
      });
    }

    return Dispute.fromJson(res);
  }

  Future<List<Dispute>> getDisputesForContract(String contractId) async {
    try {
      final res = await _supabase
          .from('disputes')
          .select('*')
          .eq('contract_id', contractId)
          .order('created_at', ascending: false);

      return (res as List).map((j) => Dispute.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Dispute?> getDisputeById(String id) async {
    try {
      final res = await _supabase.from('disputes').select('*').eq('id', id).maybeSingle();
      if (res == null) return null;
      return Dispute.fromJson(res);
    } catch (_) {
      return null;
    }
  }

  Future<void> addDisputeMessage({
    required String disputeId,
    required String message,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');

    await _supabase.from('dispute_messages').insert({
      'dispute_id': disputeId,
      'sender_id': user.id,
      'message': message.trim(),
      'attachments': attachments,
      'is_staff': false,
    });
  }
}
