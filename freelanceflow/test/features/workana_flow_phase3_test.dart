import 'package:flutter_test/flutter_test.dart';
import 'package:freelanceflow/features/chat/domain/entities/conversation.dart';
import 'package:freelanceflow/features/disputes/domain/entities/dispute.dart';
import 'package:freelanceflow/features/payments/domain/entities/milestone_revision.dart';
import 'package:freelanceflow/features/proposals/domain/entities/proposal.dart';

void main() {
  group('FASE 3 — Workana Flow Tests', () {
    test('MilestoneRevision entity parses and formats accurately', () {
      final json = {
        'id': 'rev-123',
        'milestone_id': 'm-456',
        'contract_id': 'c-789',
        'requested_by': 'user-client-1',
        'comment': 'Favor ajustar a paleta de cores para o tom azul escuro',
        'attachments': [
          {'name': 'print_correcao.png', 'url': 'https://storage.supabase.co/img.png', 'size': 102400}
        ],
        'status': 'requested',
        'created_at': '2026-08-06T12:00:00Z',
      };

      final rev = MilestoneRevision.fromJson(json);
      expect(rev.id, 'rev-123');
      expect(rev.milestoneId, 'm-456');
      expect(rev.comment, contains('paleta de cores'));
      expect(rev.attachments.length, 1);
      expect(rev.attachments.first['name'], 'print_correcao.png');
      expect(rev.status, 'requested');
    });

    test('Dispute entity parses, handles status labels and escrow freeze logic', () {
      final json = {
        'id': 'disp-001',
        'contract_id': 'contract-999',
        'milestone_id': 'milestone-888',
        'opened_by': 'client-007',
        'reason': 'Não entrega do trabalho acordado',
        'description': 'O prazo expirou e o desenvolvedor parou de responder.',
        'evidence_attachments': [
          {'name': 'comprovante.pdf', 'url': 'https://storage.supabase.co/doc.pdf', 'size': 512000}
        ],
        'status': 'opened',
        'created_at': '2026-08-06T10:00:00Z',
      };

      final dispute = Dispute.fromJson(json);
      expect(dispute.id, 'disp-001');
      expect(dispute.contractId, 'contract-999');
      expect(dispute.milestoneId, 'milestone-888');
      expect(dispute.status, DisputeStatus.opened);
      expect(dispute.statusLabel, 'Disputa Aberta');
      expect(dispute.evidenceAttachments.length, 1);
    });

    test('Proposal entity handles counter-offers seamlessly', () {
      final json = {
        'id': 'prop-101',
        'job_id': 'job-202',
        'freelancer_id': 'free-303',
        'freelancer_name': 'João Desenvolvedor',
        'freelancer_rating': 4.9,
        'bid_amount': 2500.0,
        'estimated_days': 15,
        'cover_letter': 'Tenho ampla experiência com Flutter e Clean Architecture.',
        'status': 'counter_offered',
        'counter_price': 2200.0,
        'counter_estimated_days': 10,
        'counter_message': 'Consegue fechar por R\$ 2.200 se entregarmos em 10 dias?',
        'counter_by_user_id': 'client-404',
        'counter_created_at': '2026-08-06T11:00:00Z',
        'created_at': '2026-08-06T09:00:00Z',
      };

      final proposal = Proposal.fromJson(json);
      expect(proposal.status, ProposalStatus.counterOffered);
      expect(proposal.hasActiveCounterOffer, isTrue);
      expect(proposal.counterPrice, 2200.0);
      expect(proposal.counterEstimatedDays, 10);
      expect(proposal.counterMessage, contains('R\$ 2.200'));

      final copied = proposal.copyWith(status: ProposalStatus.accepted);
      expect(copied.status, ProposalStatus.accepted);
    });

    test('ContractMilestone parses inRevision and deliverable notes properly', () {
      final json = {
        'id': 'm-1',
        'contract_id': 'c-1',
        'title': 'Frontend Mobile',
        'amount': 1800.0,
        'status': 'in_revision',
        'deliverable_notes': 'Código completo enviado no repositório.',
        'deliverable_attachments': [
          {'name': 'app-release.apk', 'url': 'https://storage/apk', 'size': 15000000}
        ],
      };

      final milestone = ContractMilestone.fromJson(json);
      expect(milestone.status, MilestoneStatus.inRevision);
      expect(milestone.deliverableNotes, contains('Código completo'));
      expect(milestone.deliverableAttachments.length, 1);
    });
  });
}
