import 'package:flutter_test/flutter_test.dart';
import 'package:freelanceflow/core/utils/currency_formatter.dart';
import 'package:freelanceflow/features/auth/domain/entities/user_profile.dart';
import 'package:freelanceflow/features/chat/domain/entities/chat_message.dart';
import 'package:freelanceflow/features/chat/domain/entities/conversation.dart';
import 'package:freelanceflow/features/jobs/domain/entities/job.dart';
import 'package:freelanceflow/features/payments/domain/entities/transaction.dart';
import 'package:freelanceflow/features/proposals/domain/entities/proposal.dart';

void main() {
  group('Core Formatter Tests', () {
    test('CurrencyFormatter formats BRL correctly', () {
      final formatted = CurrencyFormatter.format(1500.0);
      expect(formatted, contains('1.500,00'));
    });

    test('CurrencyFormatter formats range correctly', () {
      final range = CurrencyFormatter.formatRange(1000.0, 2500.0);
      expect(range, contains('1.000,00'));
      expect(range, contains('2.500,00'));
    });
  });

  group('Domain Entities Tests', () {
    test('UserProfile role parsing works as expected', () {
      expect(UserRole.fromString('client'), UserRole.client);
      expect(UserRole.fromString('freelancer'), UserRole.freelancer);
      expect(UserRole.fromString('admin'), UserRole.admin);
      expect(UserRole.fromString('unknown'), UserRole.freelancer);
    });

    test('Job entity parses and serializes correctly', () {
      final job = Job(
        id: 'job-123',
        clientId: 'client-1',
        clientName: 'Cliente Teste',
        title: 'App Flutter',
        category: 'Mobile',
        description: 'Desenvolver app mobile em Flutter com Clean Architecture',
        budgetMin: 3000.0,
        budgetMax: 5000.0,
        createdAt: DateTime.now(),
      );

      final json = job.toJson();
      expect(json['title'], 'App Flutter');
      expect(json['budget_min'], 3000.0);
      expect(json['budget_max'], 5000.0);
    });

    test('Proposal entity parses and serializes correctly', () {
      final proposal = Proposal(
        id: 'prop-1',
        jobId: 'job-1',
        freelancerId: 'user-1',
        freelancerName: 'Freelancer Teste',
        bidAmount: 4000.0,
        estimatedDays: 10,
        coverLetter: 'Experiência comprovada em Flutter e Supabase',
        proposedMilestones: [
          const ProposedMilestone(title: 'Marco 1', amount: 2000.0, days: 5),
          const ProposedMilestone(title: 'Marco 2', amount: 2000.0, days: 5),
        ],
        createdAt: DateTime.now(),
      );

      final json = proposal.toJson();
      expect(json['bid_amount'], 4000.0);
      expect(json['amount'], 4000.0);
      expect(json['cover_letter'], 'Experiência comprovada em Flutter e Supabase');
      expect(json['message'], 'Experiência comprovada em Flutter e Supabase');
      expect(json['estimated_days'], 10);
      expect((json['proposed_milestones'] as List).length, 2);

      // Verify fromJson works when database returns 'amount' and 'message'
      final parsed = Proposal.fromJson({
        'id': 'prop-2',
        'job_id': 'job-1',
        'freelancer_id': 'user-1',
        'amount': 3500.0,
        'message': 'Mensagem da proposta',
        'estimated_days': 7,
      });
      expect(parsed.bidAmount, 3500.0);
      expect(parsed.coverLetter, 'Mensagem da proposta');
    });

    test('ChatMessage parses types correctly', () {
      final textMsg = ChatMessage.fromJson({
        'id': 'msg-1',
        'conversation_id': 'conv-1',
        'sender_id': 'user-1',
        'content': 'Olá!',
        'message_type': 'text',
        'created_at': DateTime.now().toIso8601String(),
      });
      expect(textMsg.messageType, MessageType.text);

      final sysMsg = ChatMessage.fromJson({
        'id': 'msg-2',
        'conversation_id': 'conv-1',
        'sender_id': 'user-1',
        'content': 'Marco aprovado',
        'message_type': 'system_event',
        'created_at': DateTime.now().toIso8601String(),
      });
      expect(sysMsg.messageType, MessageType.systemEvent);
    });

    test('ContractMilestone parses statuses correctly', () {
      final milestone = ContractMilestone.fromJson({
        'id': 'ms-1',
        'contract_id': 'c-1',
        'title': 'Design',
        'amount': 1200.0,
        'status': 'funded_in_escrow',
      });
      expect(milestone.status, MilestoneStatus.fundedInEscrow);
      expect(milestone.amount, 1200.0);
    });

    test('Job entity serializes status to snake_case for PostgreSQL compatibility', () {
      final job = Job(
        id: 'job-1',
        clientId: 'client-1',
        clientName: 'Cliente',
        title: 'Vaga Teste',
        category: 'Mobile',
        description: 'Descrição',
        budgetMin: 1000,
        budgetMax: 2000,
        status: JobStatus.inProgress,
        createdAt: DateTime.now(),
      );

      final json = job.toJson();
      expect(json['status'], 'in_progress');
    });

    test('ContractMilestone serializes status to snake_case for PostgreSQL compatibility', () {
      const milestone = ContractMilestone(
        id: 'ms-1',
        contractId: 'c-1',
        title: 'Entrega Final',
        amount: 2500.0,
        status: MilestoneStatus.approvedAndReleased,
      );

      final json = milestone.toJson();
      expect(json['status'], 'approved_and_released');
    });

    test('UserProfile handles wallet_balance and escrow_balance properly', () {
      final user = UserProfile.fromJson({
        'id': 'user-123',
        'email': 'dev@test.com',
        'full_name': 'Dev Freelance',
        'role': 'freelancer',
        'wallet_balance': 3450.50,
        'escrow_balance': 1200.00,
      });

      expect(user.walletBalance, 3450.50);
      expect(user.escrowBalance, 1200.00);

      final json = user.toJson();
      expect(json['wallet_balance'], 3450.50);
      expect(json['escrow_balance'], 1200.00);
    });

    test('Avatar safe initial extractor handles empty and spaces gracefully', () {
      String getInitial(String? name) {
        return (name != null && name.trim().isNotEmpty) ? name.trim()[0].toUpperCase() : 'U';
      }

      expect(getInitial(''), 'U');
      expect(getInitial('   '), 'U');
      expect(getInitial(null), 'U');
      expect(getInitial('Luiz'), 'L');
      expect(getInitial(' carlos'), 'C');
    });

    test('WalletTransaction parses credit/debit correctly', () {
      final credit = WalletTransaction.fromJson({
        'id': 'tx-1',
        'user_id': 'u-1',
        'type': 'escrow_release',
        'amount': 2500.0,
        'status': 'completed',
      });
      expect(credit.isCredit, isTrue);

      final debit = WalletTransaction.fromJson({
        'id': 'tx-2',
        'user_id': 'u-1',
        'type': 'payout_pix',
        'amount': 1000.0,
        'status': 'completed',
      });
      expect(debit.isCredit, isFalse);
    });

    test('Proposal parses payload from v_job_proposals view seamlessly', () {
      final viewData = {
        'id': 'prop-v1',
        'job_id': 'job-456',
        'freelancer_id': 'free-789',
        'freelancer_name': 'Ana Silva',
        'freelancer_rating': 4.9,
        'bid_amount': 2800.0,
        'amount': 2800.0,
        'estimated_days': 15,
        'cover_letter': 'Desenvolvedora Flutter Sênior',
        'message': 'Desenvolvedora Flutter Sênior',
        'status': 'pending',
        'proposed_milestones': [
          {'title': 'MVP 1', 'amount': 1400.0, 'days': 7},
          {'title': 'MVP 2', 'amount': 1400.0, 'days': 8},
        ],
        'created_at': '2026-08-04T12:00:00Z',
      };

      final proposal = Proposal.fromJson(viewData);
      expect(proposal.id, 'prop-v1');
      expect(proposal.freelancerName, 'Ana Silva');
      expect(proposal.freelancerRating, 4.9);
      expect(proposal.bidAmount, 2800.0);
      expect(proposal.estimatedDays, 15);
      expect(proposal.coverLetter, 'Desenvolvedora Flutter Sênior');
      expect(proposal.status, ProposalStatus.pending);
      expect(proposal.proposedMilestones.length, 2);
    });

    test('Proposal status conversions and parseStatus work bidirectionally', () {
      expect(Proposal.statusToString(ProposalStatus.accepted), 'accepted');
      expect(Proposal.statusToString(ProposalStatus.rejected), 'rejected');
      expect(Proposal.statusToString(ProposalStatus.counterOffered), 'counter_offered');
      expect(Proposal.statusToString(ProposalStatus.pending), 'pending');

      expect(Proposal.parseStatus('accepted'), ProposalStatus.accepted);
      expect(Proposal.parseStatus('rejected'), ProposalStatus.rejected);
      expect(Proposal.parseStatus('counter_offered'), ProposalStatus.counterOffered);
      expect(Proposal.parseStatus('pending'), ProposalStatus.pending);
      expect(Proposal.parseStatus(null), ProposalStatus.pending);
    });

    test('Proposal serializes into Supabase-compatible payload with amount and cover_letter', () {
      final p = Proposal(
        id: 'prop-uuid-123',
        jobId: 'job-uuid-456',
        freelancerId: 'free-uuid-789',
        freelancerName: 'Carlos Dev',
        freelancerRating: 4.8,
        bidAmount: 1500.0,
        estimatedDays: 10,
        coverLetter: 'Experiência comprovada em Flutter e Supabase',
        proposedMilestones: const [
          ProposedMilestone(title: 'Sprint 1', amount: 750, days: 5),
          ProposedMilestone(title: 'Sprint 2', amount: 750, days: 5),
        ],
        createdAt: DateTime(2026, 8, 4),
      );

      final json = p.toJson();
      expect(json['job_id'], 'job-uuid-456');
      expect(json['freelancer_id'], 'free-uuid-789');
      expect(json['bid_amount'], 1500.0);
      expect(json['estimated_days'], 10);
      expect(json['cover_letter'], 'Experiência comprovada em Flutter e Supabase');
      expect(json['status'], 'pending');
    });
  });
}

