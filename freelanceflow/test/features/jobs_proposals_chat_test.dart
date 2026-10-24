import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/features/chat/domain/entities/conversation.dart';
import 'package:trabalhei/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:trabalhei/features/jobs/domain/entities/job.dart';
import 'package:trabalhei/features/proposals/domain/entities/proposal.dart';
import 'package:trabalhei/features/proposals/domain/entities/proposal_quota.dart';

Map<String, dynamic> _jobJson({String? featuredUntil}) => {
  'id': 'j1',
  'client_id': 'c1',
  'title': 'App de delivery',
  'category': 'Mobile',
  'description': 'Preciso de um app completo.',
  'budget_min': 1000,
  'budget_max': 3000,
  'status': 'open',
  'featured_until': featuredUntil,
  'profiles': {'full_name': 'Cliente X', 'rating': 4.5},
  'proposals': [
    {'count': 3},
  ],
  'created_at': '2026-10-01T10:00:00Z',
};

void main() {
  group('Job', () {
    test('interpreta cliente, contagem de propostas e orçamento', () {
      final job = Job.fromJson(_jobJson());
      expect(job.clientName, 'Cliente X');
      expect(job.clientRating, 4.5);
      expect(job.proposalsCount, 3);
      expect(job.budgetMax, 3000);
    });

    test('destaque vale somente enquanto featured_until está no futuro', () {
      final future = DateTime.now().add(const Duration(days: 2));
      final past = DateTime.now().subtract(const Duration(days: 2));
      expect(
        Job.fromJson(_jobJson(featuredUntil: future.toIso8601String()))
            .isFeatured,
        isTrue,
      );
      expect(
        Job.fromJson(_jobJson(featuredUntil: past.toIso8601String()))
            .isFeatured,
        isFalse,
      );
      expect(Job.fromJson(_jobJson()).isFeatured, isFalse);
    });

    test('toWriteJson não envia colunas protegidas pelo servidor', () {
      final json = Job.fromJson(_jobJson()).toWriteJson();
      for (final protectedColumn in [
        'id',
        'client_id',
        'status',
        'featured_until',
        'is_featured',
      ]) {
        expect(json.containsKey(protectedColumn), isFalse, reason: protectedColumn);
      }
      expect(json['title'], 'App de delivery');
    });
  });

  group('Proposal', () {
    test('lê contraproposta ativa e dados do freelancer', () {
      final p = Proposal.fromJson({
        'id': 'p1',
        'job_id': 'j1',
        'freelancer_id': 'f1',
        'bid_amount': 2000,
        'estimated_days': 10,
        'cover_letter': 'Olá',
        'status': 'counter_offered',
        'counter_price': 1800,
        'counter_estimated_days': 12,
        'profiles': {'full_name': 'Ana', 'rating': 0},
        'created_at': '2026-10-02T10:00:00Z',
      });
      expect(p.status, ProposalStatus.counterOffered);
      expect(p.hasActiveCounterOffer, isTrue);
      expect(p.counterPrice, 1800);
      expect(p.freelancerName, 'Ana');
      expect(p.freelancerRating, 0);
    });

    test('status desconhecido vira pendente', () {
      expect(Proposal.parseStatus('???'), ProposalStatus.pending);
    });
  });

  group('ProposalQuota', () {
    test('plano grátis calcula o restante e esgota no limite', () {
      final q = ProposalQuota.fromJson({
        'is_pro': false,
        'monthly_limit': 5,
        'used': 5,
      });
      expect(q.remaining, 0);
      expect(q.isExhausted, isTrue);
      expect(q.isUnlimited, isFalse);
    });

    test('plano Pro é ilimitado e nunca esgota', () {
      final q = ProposalQuota.fromJson({
        'is_pro': true,
        'monthly_limit': null,
        'used': 99,
      });
      expect(q.isUnlimited, isTrue);
      expect(q.isExhausted, isFalse);
    });
  });

  group('ContractMilestone', () {
    test('interpreta o ciclo de status sem custódia financeira', () {
      ContractMilestone m(String status) => ContractMilestone.fromJson({
        'id': 'm1',
        'contract_id': 'c1',
        'title': 'Entrega',
        'amount': 500,
        'status': status,
      });
      expect(m('pending').status, MilestoneStatus.pending);
      expect(m('submitted').status, MilestoneStatus.submitted);
      expect(m('in_revision').status, MilestoneStatus.inRevision);
      expect(m('approved').status, MilestoneStatus.approved);
      expect(m('qualquer').status, MilestoneStatus.pending);
    });
  });

  group('Estatísticas do dashboard', () {
    test('taxa de sucesso = aceitas ÷ enviadas', () {
      const stats = FreelancerDashboardStats(
        activeContractsCount: 1,
        completedContractsCount: 2,
        pendingProposalsCount: 3,
        sentProposalsCount: 8,
        acceptedProposalsCount: 2,
        monthlyCompleted: [0, 0, 0, 1, 0, 1],
      );
      expect(stats.proposalSuccessRate, 25);
    });

    test('sem propostas enviadas a taxa é zero (sem divisão por zero)', () {
      const stats = FreelancerDashboardStats(
        activeContractsCount: 0,
        completedContractsCount: 0,
        pendingProposalsCount: 0,
        sentProposalsCount: 0,
        acceptedProposalsCount: 0,
        monthlyCompleted: [0, 0, 0, 0, 0, 0],
      );
      expect(stats.proposalSuccessRate, 0);
    });
  });
}
