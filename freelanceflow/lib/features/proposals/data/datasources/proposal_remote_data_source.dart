import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/proposal.dart';

class ProposalRemoteDataSource {
  final SupabaseClient _supabase;

  ProposalRemoteDataSource(this._supabase);

  Future<List<Proposal>> getProposalsByJob(String jobId) async {
    try {
      final response = await _supabase
          .from('v_job_proposals')
          .select('*')
          .eq('job_id', jobId)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Proposal.fromJson(json as Map<String, dynamic>)).toList();
    } catch (_) {
      final response = await _supabase
          .from('proposals')
          .select('*, profiles!freelancer_id(full_name, rating)')
          .eq('job_id', jobId)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Proposal.fromJson(json as Map<String, dynamic>)).toList();
    }
  }

  Future<List<Proposal>> getFreelancerProposals(String freelancerId) async {
    try {
      final response = await _supabase
          .from('v_job_proposals')
          .select('*')
          .eq('freelancer_id', freelancerId)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Proposal.fromJson(json as Map<String, dynamic>)).toList();
    } catch (_) {
      final response = await _supabase
          .from('proposals')
          .select('*, profiles!freelancer_id(full_name, rating)')
          .eq('freelancer_id', freelancerId)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Proposal.fromJson(json as Map<String, dynamic>)).toList();
    }
  }

  Future<Proposal> submitProposal(Proposal proposal) async {
    final user = _supabase.auth.currentUser;
    final freelancerId = user?.id ?? proposal.freelancerId;
    final payload = proposal.toJson();
    payload['freelancer_id'] = freelancerId;
    payload['amount'] = proposal.bidAmount;
    payload['bid_amount'] = proposal.bidAmount;
    payload['message'] = proposal.coverLetter;
    payload['cover_letter'] = proposal.coverLetter;

    if (payload['id'] == null ||
        payload['id'].toString().isEmpty ||
        !payload['id'].toString().contains('-') ||
        payload['id'].toString().startsWith('prop-')) {
      payload.remove('id');
    }

    // Verificar se o freelancer já possui proposta cadastrada para esta vaga
    final existing = await _supabase
        .from('proposals')
        .select('id')
        .eq('job_id', proposal.jobId)
        .eq('freelancer_id', freelancerId)
        .maybeSingle();

    Map<String, dynamic> response;
    if (existing != null) {
      final existingId = existing['id'] as String;
      payload.remove('id');
      payload['status'] = 'pending';
      payload['updated_at'] = DateTime.now().toIso8601String();

      response = await _supabase
          .from('proposals')
          .update(payload)
          .eq('id', existingId)
          .select('*, profiles!freelancer_id(full_name, rating)')
          .single();
    } else {
      response = await _supabase
          .from('proposals')
          .insert(payload)
          .select('*, profiles!freelancer_id(full_name, rating)')
          .single();
    }

    return Proposal.fromJson(response);
  }

  Future<void> updateStatus(String proposalId, ProposalStatus status) async {
    final statusStr = Proposal.statusToString(status);
    await _supabase.from('proposals').update({'status': statusStr}).eq('id', proposalId);

    if (status == ProposalStatus.accepted) {
      final propData = await _supabase
          .from('proposals')
          .select('*, jobs!job_id(client_id, title, budget_max)')
          .eq('id', proposalId)
          .maybeSingle();

      if (propData != null) {
        final jobId = propData['job_id'] as String;
        final freelancerId = propData['freelancer_id'] as String;
        final clientId = propData['jobs']?['client_id'] as String? ?? _supabase.auth.currentUser?.id;
        final totalAmount = (propData['bid_amount'] ?? propData['amount'] as num?)?.toDouble() ?? 0.0;
        final platformFee = totalAmount * 0.10;

        if (clientId != null) {
          // 1. Criar contrato
          final contractResponse = await _supabase.from('contracts').insert({
            'job_id': jobId,
            'proposal_id': proposalId,
            'client_id': clientId,
            'freelancer_id': freelancerId,
            'total_amount': totalAmount,
            'platform_fee': platformFee,
            'escrow_amount': totalAmount,
            'status': 'active',
          }).select().single();

          final contractId = contractResponse['id'] as String;

          // 2. Inserir marcos de entrega
          final rawMilestones = propData['proposed_milestones'] as List<dynamic>? ?? [];
          for (final m in rawMilestones) {
            if (m is Map<String, dynamic>) {
              await _supabase.from('milestones').insert({
                'contract_id': contractId,
                'title': m['title'] ?? 'Marco',
                'amount': (m['amount'] as num?)?.toDouble() ?? (totalAmount / (rawMilestones.isNotEmpty ? rawMilestones.length : 1)),
                'status': 'funded_in_escrow',
              });
            }
          }

          // 3. Atualizar status da vaga
          await _supabase.from('jobs').update({'status': 'in_progress'}).eq('id', jobId);

          // 4. Criar ou vincular conversa no chat
          final convQuery = await _supabase
              .from('conversations')
              .select('id')
              .eq('job_id', jobId);
          final List<dynamic> existingConvs = convQuery as List<dynamic>;
          String? convId;

          if (existingConvs.isNotEmpty) {
            convId = existingConvs.first['id'] as String;
            await _supabase.from('conversations').update({
              'contract_id': contractId,
              'client_id': clientId,
              'freelancer_id': freelancerId,
              'participant_a': clientId,
              'participant_b': freelancerId,
              'last_message_at': DateTime.now().toIso8601String(),
            }).eq('id', convId);
          } else {
            final newConv = await _supabase.from('conversations').insert({
              'job_id': jobId,
              'contract_id': contractId,
              'client_id': clientId,
              'freelancer_id': freelancerId,
              'participant_a': clientId,
              'participant_b': freelancerId,
              'last_message_at': DateTime.now().toIso8601String(),
            }).select('id').single();
            convId = newConv['id'] as String;
          }

          // 5. Enviar mensagem de boas-vindas do sistema no chat
          await _supabase.from('messages').insert({
            'conversation_id': convId,
            'sender_id': clientId,
            'content': '🎉 Proposta aceita! O contrato foi iniciado e o valor total está protegido no Escrow.',
            'message_type': 'system_event',
            'is_read': false,
          });
        }
      }
    }
  }
}
