import '../../../jobs/domain/entities/job.dart';
import 'proposal.dart';

/// O que o freelancer pode fazer numa vaga, espelhando as regras de
/// `submit_proposal` no servidor: só envia ou edita com a vaga aberta e a
/// proposta ainda pendente; contraproposta precisa de resposta antes.
enum ProposalAction {
  send,
  edit,
  respondCounterOffer,
  accepted,
  rejected,
  jobClosed;

  static ProposalAction of(JobStatus jobStatus, Proposal? proposal) {
    switch (proposal?.status) {
      case ProposalStatus.accepted:
        return ProposalAction.accepted;
      case ProposalStatus.rejected:
        return ProposalAction.rejected;
      case _ when jobStatus != JobStatus.open:
        return ProposalAction.jobClosed;
      case ProposalStatus.counterOffered:
        return ProposalAction.respondCounterOffer;
      case ProposalStatus.pending:
        return ProposalAction.edit;
      case null:
        return ProposalAction.send;
    }
  }

  bool get canSubmit => this == send || this == edit;

  /// Explicação mostrada quando não há envio/edição disponível.
  String? get blockedReason => switch (this) {
    send || edit => null,
    respondCounterOffer =>
      'Para alterar sua proposta, recuse a contraproposta acima.',
    accepted => 'Sua proposta foi aceita. Acompanhe o contrato pelo chat.',
    rejected => 'Esta proposta não foi selecionada pelo cliente.',
    jobClosed => 'Esta vaga não está mais recebendo propostas.',
  };
}
