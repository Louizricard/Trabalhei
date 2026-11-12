import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trabalhei/features/chat/domain/entities/conversation.dart';
import 'package:trabalhei/features/chat/domain/repositories/chat_repository.dart';
import 'package:trabalhei/features/chat/presentation/providers/chat_provider.dart';
import 'package:trabalhei/features/chat/presentation/widgets/cancel_contract_dialog.dart';
import 'package:trabalhei/features/chat/presentation/widgets/chat_delivery_action_banner.dart';

class _User {
  final String id;
  const _User(this.id);
}

class _ChatRepository implements ChatRepository {
  final calls = <(String, String)>[];
  Object? failure;

  @override
  Future<void> cancelContract({
    required String contractId,
    required String reason,
  }) async {
    calls.add((contractId, reason));
    if (failure != null) throw failure!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Conversation _conversation({
  String contractStatus = 'active',
  MilestoneStatus milestone = MilestoneStatus.pending,
}) => Conversation(
  id: 'conv',
  contractId: 'contract',
  contractStatus: contractStatus,
  clientId: 'client',
  freelancerId: 'freelancer',
  jobTitle: 'Site institucional',
  otherParticipantId: 'freelancer',
  otherParticipantName: 'Ana',
  lastMessage: '',
  lastMessageAt: DateTime(2026),
  milestones: [
    ContractMilestone(
      id: 'm1',
      contractId: 'contract',
      title: 'Entrega',
      amount: 100,
      status: milestone,
    ),
  ],
);

/// Abre o diálogo; o resultado de `show` fica em [result] ao fechar.
Future<ValueNotifier<bool?>> _openDialog(
  WidgetTester tester,
  _ChatRepository repo,
) async {
  final result = ValueNotifier<bool?>(null);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result.value =
                await CancelContractDialog.show(context, _conversation()),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  group('CancelContractDialog', () {
    testWidgets('exige motivo de pelo menos 10 caracteres', (tester) async {
      final repo = _ChatRepository();
      await _openDialog(tester, repo);
      await tester.enterText(
        find.byKey(const Key('cancel-contract-reason')),
        'curto',
      );
      await tester.tap(find.byKey(const Key('confirm-cancel-contract')));
      await tester.pumpAndSettle();
      expect(find.textContaining('mínimo de 10 caracteres'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('encerra com o motivo informado e fecha', (tester) async {
      final repo = _ChatRepository();
      final closed = await _openDialog(tester, repo);
      await tester.enterText(
        find.byKey(const Key('cancel-contract-reason')),
        '  O freelancer parou de responder.  ',
      );
      await tester.tap(find.byKey(const Key('confirm-cancel-contract')));
      await tester.pumpAndSettle();
      expect(repo.calls, [('contract', 'O freelancer parou de responder.')]);
      expect(closed.value, isTrue);
      expect(find.byType(CancelContractDialog), findsNothing);
    });

    testWidgets('mostra erro do servidor sem fechar', (tester) async {
      final repo = _ChatRepository()
        ..failure = const PostgrestException(message: 'CONTRACT_NOT_ACTIVE');
      await _openDialog(tester, repo);
      await tester.enterText(
        find.byKey(const Key('cancel-contract-reason')),
        'Motivo válido para encerrar.',
      );
      await tester.tap(find.byKey(const Key('confirm-cancel-contract')));
      await tester.pumpAndSettle();
      expect(find.text('Este contrato não está ativo.'), findsOneWidget);
      expect(find.byType(CancelContractDialog), findsOneWidget);
    });
  });

  group('ChatDeliveryActionBanner', () {
    Future<void> pump(WidgetTester tester, Conversation conversation) =>
        tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ChatDeliveryActionBanner(
                  conversation: conversation,
                  currentUser: const _User('client'),
                ),
              ),
            ),
          ),
        );

    testWidgets('contrato encerrado não oferece revisar nem entregar', (
      tester,
    ) async {
      await pump(
        tester,
        _conversation(
          contractStatus: 'cancelled',
          milestone: MilestoneStatus.submitted,
        ),
      );
      expect(
        find.byKey(const Key('contract-cancelled-banner')),
        findsOneWidget,
      );
      expect(find.text('Revisar & Aprovar'), findsNothing);
    });

    testWidgets('contrato ativo com entrega mostra revisar ao cliente', (
      tester,
    ) async {
      await pump(tester, _conversation(milestone: MilestoneStatus.submitted));
      expect(find.text('Revisar & Aprovar'), findsOneWidget);
    });
  });
}
