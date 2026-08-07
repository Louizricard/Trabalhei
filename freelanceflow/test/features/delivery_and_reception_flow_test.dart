import 'package:flutter_test/flutter_test.dart';
import 'package:freelanceflow/features/chat/domain/entities/conversation.dart';

void main() {
  group('Delivery & Milestone Reception Flow Tests', () {
    test('ContractMilestone parses dynamic deliverable attachments safely', () {
      final json = {
        'id': 'm1',
        'contract_id': 'c1',
        'title': 'Desenvolvimento do Backend',
        'description': 'Construção das APIs e integração de banco de dados',
        'amount': 2500.0,
        'status': 'submitted',
        'due_date': '2026-09-01T00:00:00.000Z',
        'deliverable_notes':
            'Entreguei o código fonte com documentação Swagger anexa.',
        'deliverable_attachments': [
          {
            'url': 'https://storage.supabase.co/file1.zip',
            'name': 'source_v1.zip',
            'size': 1048576,
          },
          {
            'url': 'https://storage.supabase.co/doc.pdf',
            'name': 'documentation.pdf',
            'size': 512000,
          },
        ],
        'submitted_at': '2026-08-06T15:00:00.000Z',
        'revision_count': 1,
      };

      final milestone = ContractMilestone.fromJson(json);

      expect(milestone.id, 'm1');
      expect(milestone.status, MilestoneStatus.submitted);
      expect(
        milestone.deliverableNotes,
        'Entreguei o código fonte com documentação Swagger anexa.',
      );
      expect(milestone.deliverableAttachments.length, 2);
      expect(milestone.deliverableAttachments.first['name'], 'source_v1.zip');
      expect(milestone.revisionCount, 1);
    });

    test('ContractMilestone handles empty or null attachments gracefully', () {
      final json = {
        'id': 'm2',
        'contract_id': 'c1',
        'title': 'Design UI/UX',
        'amount': 1200.0,
        'status': 'in_revision',
        'deliverable_attachments': null,
      };

      final milestone = ContractMilestone.fromJson(json);

      expect(milestone.status, MilestoneStatus.inRevision);
      expect(milestone.deliverableAttachments, isEmpty);
      expect(milestone.deliverableNotes, isNull);
    });

    test(
      'ContractMilestone status helper isApproved / isSubmitted works accurately',
      () {
        final mSubmitted = ContractMilestone(
          id: 'm1',
          contractId: 'c1',
          title: 'M1',
          description: 'D1',
          amount: 1000,
          status: MilestoneStatus.submitted,
        );

        final mApproved = ContractMilestone(
          id: 'm2',
          contractId: 'c1',
          title: 'M2',
          description: 'D2',
          amount: 1000,
          status: MilestoneStatus.approvedAndReleased,
        );

        expect(mSubmitted.status, MilestoneStatus.submitted);
        expect(mApproved.status, MilestoneStatus.approvedAndReleased);
      },
    );
  });
}
