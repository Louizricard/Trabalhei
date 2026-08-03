import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/proposal.dart';

class ProposalRemoteDataSource {
  final SupabaseClient _supabase;

  ProposalRemoteDataSource(this._supabase);

  Future<List<Proposal>> getProposalsByJob(String jobId) async {
    final response = await _supabase
        .from('proposals')
        .select('*, profiles!freelancer_id(full_name, rating)')
        .eq('job_id', jobId)
        .order('created_at', ascending: false);

    final List<dynamic> data = response as List<dynamic>;
    return data.map((json) => Proposal.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<Proposal>> getFreelancerProposals(String freelancerId) async {
    final response = await _supabase
        .from('proposals')
        .select('*, profiles!freelancer_id(full_name, rating)')
        .eq('freelancer_id', freelancerId)
        .order('created_at', ascending: false);

    final List<dynamic> data = response as List<dynamic>;
    return data.map((json) => Proposal.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Proposal> submitProposal(Proposal proposal) async {
    final user = _supabase.auth.currentUser;
    final payload = proposal.toJson();
    if (user != null) {
      payload['freelancer_id'] = user.id;
    }
    if (!payload['id'].toString().contains('-') || payload['id'].toString().startsWith('prop-')) {
      payload.remove('id');
    }

    final response = await _supabase
        .from('proposals')
        .insert(payload)
        .select('*, profiles!freelancer_id(full_name, rating)')
        .single();

    return Proposal.fromJson(response);
  }

  Future<void> updateStatus(String proposalId, ProposalStatus status) async {
    await _supabase.from('proposals').update({'status': status.name}).eq('id', proposalId);

    if (status == ProposalStatus.accepted) {
      final propData = await _supabase
          .from('proposals')
          .select('*, jobs!job_id(client_id, budget_max)')
          .eq('id', proposalId)
          .maybeSingle();

      if (propData != null) {
        final jobId = propData['job_id'] as String;
        final freelancerId = propData['freelancer_id'] as String;
        final clientId = propData['jobs']?['client_id'] as String? ?? _supabase.auth.currentUser?.id;
        final totalAmount = (propData['bid_amount'] as num?)?.toDouble() ?? 0.0;
        final platformFee = totalAmount * 0.10;

        if (clientId != null) {
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

          final rawMilestones = propData['proposed_milestones'] as List<dynamic>? ?? [];
          for (final m in rawMilestones) {
            if (m is Map<String, dynamic>) {
              await _supabase.from('milestones').insert({
                'contract_id': contractId,
                'title': m['title'] ?? 'Marco',
                'amount': m['amount'] ?? 0.0,
                'status': 'funded_in_escrow',
              });
            }
          }

          await _supabase.from('jobs').update({'status': 'in_progress'}).eq('id', jobId);
        }
      }
    }
  }
}
