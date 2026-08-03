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
      expect(json['estimated_days'], 10);
      expect((json['proposed_milestones'] as List).length, 2);
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
  });
}
