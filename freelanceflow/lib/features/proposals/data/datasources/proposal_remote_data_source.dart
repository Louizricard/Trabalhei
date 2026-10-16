import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/proposal.dart';
import '../../domain/entities/proposal_quota.dart';

/// Toda escrita em propostas passa por funções (RPC) do servidor, que aplicam
/// a máquina de estados, a cota do plano e as notificações.
class ProposalRemoteDataSource {
  static const _select = '*, profiles!freelancer_id(full_name, rating)';

  final SupabaseClient _supabase;

  ProposalRemoteDataSource(this._supabase);

  Future<List<Proposal>> getProposalsByJob(String jobId) async {
    final response = await _supabase
        .from('proposals')
        .select(_select)
        .eq('job_id', jobId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((json) => Proposal.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<Proposal>> getFreelancerProposals(String freelancerId) async {
    final response = await _supabase
        .from('proposals')
        .select(_select)
        .eq('freelancer_id', freelancerId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((json) => Proposal.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<ProposalQuota> getQuota() async {
    final response = await _supabase.rpc('proposal_quota');
    return ProposalQuota.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<Proposal> submitProposal(Proposal proposal) async {
    final response = await _supabase.rpc(
      'submit_proposal',
      params: {
        'p_job_id': proposal.jobId,
        'p_bid_amount': proposal.bidAmount,
        'p_estimated_days': proposal.estimatedDays,
        'p_cover_letter': proposal.coverLetter,
        'p_milestones': proposal.proposedMilestones
            .map((m) => m.toJson())
            .toList(),
      },
    );
    return Proposal.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Cliente aceita a proposta; o servidor cria contrato, marcos e conversa.
  Future<Map<String, dynamic>> acceptProposal(String proposalId) async {
    final response = await _supabase.rpc(
      'accept_proposal',
      params: {'p_proposal_id': proposalId},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<void> rejectProposal(String proposalId) async {
    await _supabase.rpc(
      'reject_proposal',
      params: {'p_proposal_id': proposalId},
    );
  }

  Future<void> makeCounterOffer({
    required String proposalId,
    required double counterPrice,
    required int counterEstimatedDays,
    String? counterMessage,
  }) async {
    await _supabase.rpc(
      'make_counter_offer',
      params: {
        'p_proposal_id': proposalId,
        'p_price': counterPrice,
        'p_days': counterEstimatedDays,
        'p_message': counterMessage,
      },
    );
  }

  /// Freelancer aceita a contraproposta; o servidor cria o contrato.
  Future<Map<String, dynamic>> acceptCounterOffer(String proposalId) async {
    final response = await _supabase.rpc(
      'accept_counter_offer',
      params: {'p_proposal_id': proposalId},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<void> rejectCounterOffer(String proposalId) async {
    await _supabase.rpc(
      'reject_counter_offer',
      params: {'p_proposal_id': proposalId},
    );
  }
}
