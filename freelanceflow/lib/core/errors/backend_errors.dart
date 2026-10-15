import 'package:supabase_flutter/supabase_flutter.dart';

/// Códigos de erro levantados pelas funções do banco (`raise exception 'CODE'`)
/// e as mensagens amigáveis exibidas ao usuário.
const Map<String, String> _knownErrors = {
  'NOT_AUTHENTICATED': 'Faça login para continuar.',
  'FORBIDDEN': 'Você não tem permissão para esta ação.',
  'PROPOSAL_QUOTA_EXCEEDED':
      'Você atingiu o limite de propostas gratuitas deste mês. Assine o Pro para enviar propostas ilimitadas.',
  'ONLY_FREELANCERS_CAN_APPLY':
      'Apenas contas de freelancer podem enviar propostas.',
  'ONLY_CLIENTS_CAN_POST_JOBS': 'Apenas contas de cliente podem publicar vagas.',
  'JOB_NOT_OPEN': 'Esta vaga não está mais aberta.',
  'JOB_NOT_CANCELLABLE': 'Esta vaga não pode ser cancelada.',
  'CANNOT_APPLY_TO_OWN_JOB': 'Você não pode se candidatar à sua própria vaga.',
  'PROPOSAL_ALREADY_DECIDED': 'Esta proposta já foi decidida.',
  'PROPOSAL_NOT_FOUND': 'Proposta não encontrada.',
  'PROPOSAL_NOT_PENDING': 'Esta proposta não está mais pendente.',
  'NO_ACTIVE_COUNTER_OFFER': 'Não há contraproposta ativa nesta proposta.',
  'INVALID_COUNTER_OFFER': 'Valor ou prazo da contraproposta inválido.',
  'MILESTONE_NOT_FOUND': 'Marco não encontrado.',
  'MILESTONE_NOT_DELIVERABLE': 'Este marco não aceita entregas agora.',
  'MILESTONE_NOT_SUBMITTED': 'Este marco não possui entrega para analisar.',
  'CONTRACT_NOT_ACTIVE': 'Este contrato não está ativo.',
  'COMMENT_REQUIRED': 'Descreva o que precisa ser ajustado.',
};

/// Converte qualquer erro do backend em uma mensagem legível em português.
String friendlyError(Object error) {
  final raw = switch (error) {
    PostgrestException e => '${e.message} ${e.details ?? ''}',
    FunctionException e => _functionMessage(e),
    AuthException e => e.message,
    _ => error.toString(),
  };

  for (final entry in _knownErrors.entries) {
    if (raw.contains(entry.key)) return entry.value;
  }

  final lower = raw.toLowerCase();
  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('clientexception') ||
      lower.contains('network')) {
    return 'Sem conexão com o servidor. Verifique sua internet e tente novamente.';
  }
  if (lower.contains('row-level security') ||
      lower.contains('permission denied')) {
    return 'Você não tem permissão para esta ação.';
  }
  if (lower.contains('duplicate key')) {
    return 'Este registro já existe.';
  }
  return raw.replaceAll('Exception: ', '').trim().isEmpty
      ? 'Ocorreu um erro inesperado. Tente novamente.'
      : raw.replaceAll('Exception: ', '').trim();
}

String _functionMessage(FunctionException e) {
  final details = e.details;
  if (details is Map && details['error'] is String) {
    return details['error'] as String;
  }
  return details?.toString() ?? 'Falha ao chamar o servidor (${e.status}).';
}
