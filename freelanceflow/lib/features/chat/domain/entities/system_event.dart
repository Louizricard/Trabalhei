/// Tipos de mensagem de sistema do chat, identificados pelo início fixo do
/// texto gerado pelas funções do banco (submit_deliverable, request_revision e
/// approve_milestone). Procurar palavras soltas falha: o nome do marco pode
/// conter "Entrega", por exemplo.
enum SystemEventKind { delivery, revision, approval, other }

SystemEventKind systemEventKindOf(String content) {
  if (content.startsWith('📦 Entrega enviada')) return SystemEventKind.delivery;
  if (content.startsWith('🔄 Revisão solicitada')) {
    return SystemEventKind.revision;
  }
  if (content.startsWith('🎉 Marco') && content.contains('aprovado')) {
    return SystemEventKind.approval;
  }
  return SystemEventKind.other;
}

/// Título do marco citado na mensagem (`marco "Título"`), se houver.
String? milestoneTitleOf(String content) =>
    RegExp(r'[Mm]arco "([^"]*)"').firstMatch(content)?.group(1);
