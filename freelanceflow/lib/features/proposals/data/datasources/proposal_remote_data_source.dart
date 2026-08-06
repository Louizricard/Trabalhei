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

  Future<Map<String, dynamic>> acceptProposal(String proposalId) async {
    final response = await _supabase.rpc(
      'accept_proposal_and_create_contract',
      params: {'p_proposal_id': proposalId},
    );
    if (response is Map<String, dynamic>) {
      return response;
    }
    return Map<String, dynamic>.from(response as Map);
  }

  Future<void> updateStatus(String proposalId, ProposalStatus status) async {
    if (status == ProposalStatus.accepted) {
      await acceptProposal(proposalId);
      return;
    }
    final statusStr = Proposal.statusToString(status);
    await _supabase.from('proposals').update({'status': statusStr}).eq('id', proposalId);
  }

  Future<void> makeCounterOffer({
    required String proposalId,
    required double counterPrice,
    required int counterEstimatedDays,
    String? counterMessage,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');

    // 1. Atualizar proposta com a contraproposta
    await _supabase.from('proposals').update({
      'status': 'counter_offered',
      'counter_price': counterPrice,
      'counter_estimated_days': counterEstimatedDays,
      'counter_message': counterMessage?.trim(),
      'counter_by_user_id': user.id,
      'counter_created_at': DateTime.now().toIso8601String(),
    }).eq('id', proposalId);

    // 2. Registrar no histórico de contrapropostas
    try {
      await _supabase.from('proposal_counter_offers').insert({
        'proposal_id': proposalId,
        'offered_by': user.id,
        'amount': counterPrice,
        'estimated_days': counterEstimatedDays,
        'message': counterMessage?.trim(),
      });
    } catch (_) {}
  }

  Future<void> acceptCounterOffer(String proposalId) async {
    final prop = await _supabase.from('proposals').select('*').eq('id', proposalId).single();
    final counterPrice = (prop['counter_price'] as num?)?.toDouble() ?? (prop['bid_amount'] as num?)?.toDouble() ?? 0.0;
    final counterDays = (prop['counter_estimated_days'] as num?)?.toInt() ?? (prop['estimated_days'] as num?)?.toInt() ?? 14;

    // Atualizar valores da proposta e aceitar
    await _supabase.from('proposals').update({
      'bid_amount': counterPrice,
      'amount': counterPrice,
      'estimated_days': counterDays,
      'status': 'accepted',
    }).eq('id', proposalId);

    await updateStatus(proposalId, ProposalStatus.accepted);
  }

  Future<void> rejectCounterOffer(String proposalId) async {
    await _supabase.from('proposals').update({
      'status': 'pending',
      'counter_price': null,
      'counter_estimated_days': null,
      'counter_message': null,
    }).eq('id', proposalId);
  }
}
