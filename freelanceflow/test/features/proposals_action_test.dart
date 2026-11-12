import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/features/jobs/domain/entities/job.dart';
import 'package:trabalhei/features/proposals/domain/entities/proposal.dart';
import 'package:trabalhei/features/proposals/domain/entities/proposal_action.dart';

Proposal _proposal(ProposalStatus status) => Proposal(
  id: 'p',
  jobId: 'j',
  freelancerId: 'f',
  freelancerName: 'F',
  freelancerRating: 0,
  bidAmount: 100,
  estimatedDays: 7,
  coverLetter: 'carta',
  status: status,
  counterPrice: status == ProposalStatus.counterOffered ? 80 : null,
  createdAt: DateTime(2026),
);

void main() {
  test('vaga aberta: envia, edita pendente ou responde contraproposta', () {
    expect(ProposalAction.of(JobStatus.open, null), ProposalAction.send);
    expect(
      ProposalAction.of(JobStatus.open, _proposal(ProposalStatus.pending)),
      ProposalAction.edit,
    );
    expect(
      ProposalAction.of(
        JobStatus.open,
        _proposal(ProposalStatus.counterOffered),
      ),
      ProposalAction.respondCounterOffer,
    );
  });

  test('proposta decidida nunca oferece edição', () {
    for (final job in JobStatus.values) {
      expect(
        ProposalAction.of(job, _proposal(ProposalStatus.accepted)),
        ProposalAction.accepted,
      );
      expect(
        ProposalAction.of(job, _proposal(ProposalStatus.rejected)),
        ProposalAction.rejected,
      );
    }
  });

  test('vaga fora de open bloqueia envio e edição', () {
    for (final job in [
      JobStatus.inProgress,
      JobStatus.completed,
      JobStatus.cancelled,
    ]) {
      for (final p in [
        null,
        _proposal(ProposalStatus.pending),
        _proposal(ProposalStatus.counterOffered),
      ]) {
        final action = ProposalAction.of(job, p);
        expect(action, ProposalAction.jobClosed);
        expect(action.canSubmit, isFalse);
        expect(action.blockedReason, isNotNull);
      }
    }
  });
}
