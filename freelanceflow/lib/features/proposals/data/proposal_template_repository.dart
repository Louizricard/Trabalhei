import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/entities/proposal_template.dart';

/// Modelos de proposta. Criar e editar exige Pro (RLS); apagar e ler, não.
class ProposalTemplateRepository {
  final SupabaseClient _supabase;

  ProposalTemplateRepository(this._supabase);

  Future<List<ProposalTemplate>> list() async {
    final rows = await _supabase
        .from('proposal_templates')
        .select()
        .order('updated_at', ascending: false);
    return rows.map(ProposalTemplate.fromJson).toList();
  }

  Future<void> create({
    required String title,
    required String coverLetter,
    int? estimatedDays,
  }) => _supabase.from('proposal_templates').insert({
    'title': title.trim(),
    'cover_letter': coverLetter.trim(),
    'estimated_days': estimatedDays,
  });

  Future<void> update(
    String id, {
    required String title,
    required String coverLetter,
    int? estimatedDays,
  }) => _supabase
      .from('proposal_templates')
      .update({
        'title': title.trim(),
        'cover_letter': coverLetter.trim(),
        'estimated_days': estimatedDays,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id);

  Future<void> delete(String id) =>
      _supabase.from('proposal_templates').delete().eq('id', id);
}
