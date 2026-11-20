import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/features/admin/data/admin_repository.dart';
import 'package:trabalhei/features/admin/domain/admin_models.dart';
import 'package:trabalhei/features/admin/presentation/providers/admin_provider.dart';
import 'package:trabalhei/features/auth/domain/entities/user_profile.dart';
import 'package:trabalhei/features/auth/domain/repositories/auth_repository.dart';
import 'package:trabalhei/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:trabalhei/features/chat/domain/entities/chat_message.dart';
import 'package:trabalhei/features/chat/domain/entities/conversation.dart';
import 'package:trabalhei/features/chat/presentation/widgets/chat_safety.dart';

class _Admin implements AdminRepository {
  final blocked = <String>{};
  final sent = <(ReportTarget, String, ReportReason)>[];

  @override
  Future<Set<String>> blockedUsers() async => {...blocked};

  @override
  Future<void> blockUser(String userId) async => blocked.add(userId);

  @override
  Future<void> unblockUser(String userId) async => blocked.remove(userId);

  @override
  Future<void> report({
    required ReportTarget target,
    required String targetId,
    required ReportReason reason,
    String? details,
  }) async => sent.add((target, targetId, reason));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements AuthRepository {
  @override
  Stream<UserProfile?> get authStateChanges => const Stream.empty();

  @override
  Future<UserProfile?> getCurrentUser() async => UserProfile(
    id: 'client',
    email: 'cliente@exemplo.com',
    fullName: 'Cliente',
    role: UserRole.client,
    createdAt: DateTime(2026),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _conversation = Conversation(
  id: 'conv',
  jobTitle: 'Site institucional',
  otherParticipantId: 'ana',
  otherParticipantName: 'Ana',
  lastMessage: '',
  lastMessageAt: DateTime(2026),
);

Future<_Admin> _pump(WidgetTester tester, Widget child) async {
  final admin = _Admin();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminRepositoryProvider.overrideWithValue(admin),
        authRepositoryProvider.overrideWithValue(_Auth()),
      ],
      // Sessão carregada antes, como no app (a denúncia exige conta).
      child: Consumer(
        builder: (context, ref, _) {
          ref.watch(authProvider);
          return MaterialApp(home: Scaffold(body: child));
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return admin;
}

void main() {
  testWidgets('bloquear pede confirmação e depois oferece desbloquear', (
    tester,
  ) async {
    final admin = await _pump(
      tester,
      ChatSafetyMenu(conversation: _conversation),
    );

    await tester.tap(find.byKey(const Key('chat-safety-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bloquear Ana'));
    await tester.pumpAndSettle();
    expect(find.text('Bloquear Ana?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-block')));
    await tester.pumpAndSettle();
    expect(admin.blocked, {'ana'});
    expect(find.text('Usuário bloqueado.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chat-safety-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Desbloquear Ana'), findsOneWidget);
    await tester.tap(find.text('Desbloquear Ana'));
    await tester.pumpAndSettle();
    expect(admin.blocked, isEmpty);
  });

  testWidgets('voltar no diálogo não bloqueia', (tester) async {
    final admin = await _pump(
      tester,
      ChatSafetyMenu(conversation: _conversation),
    );
    await tester.tap(find.byKey(const Key('chat-safety-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bloquear Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();
    expect(admin.blocked, isEmpty);
  });

  testWidgets('denunciar mensagem envia o id da mensagem com o motivo', (
    tester,
  ) async {
    final message = ChatMessage(
      id: 'msg-1',
      conversationId: 'conv',
      senderId: 'ana',
      content: 'Me paga por fora',
      createdAt: DateTime(2026),
    );
    final admin = await _pump(
      tester,
      Consumer(
        builder: (context, ref, _) => TextButton(
          onPressed: () => showMessageActions(context, ref, message),
          child: const Text('segurar'),
        ),
      ),
    );
    await tester.tap(find.text('segurar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-message')));
    await tester.pumpAndSettle();
    expect(find.text('Denunciar mensagem'), findsOneWidget);
    await tester.tap(find.text('Pedido de dados ou pagamento suspeito'));
    await tester.tap(find.text('Enviar denúncia'));
    await tester.pumpAndSettle();
    expect(admin.sent, [
      (ReportTarget.message, 'msg-1', ReportReason.offPlatformPayment),
    ]);
  });

  testWidgets('aviso de bloqueio substitui o campo e desbloqueia', (
    tester,
  ) async {
    final admin = await _pump(
      tester,
      BlockedChatNotice(conversation: _conversation),
    );
    admin.blocked.add('ana');
    expect(find.text('Você bloqueou Ana.'), findsOneWidget);
    await tester.tap(find.text('Desbloquear'));
    await tester.pumpAndSettle();
    expect(admin.blocked, isEmpty);
  });

  test('denúncia de mensagem vinda da moderação é reconhecida', () {
    final r = AdminReport.fromJson({
      'id': 'r1',
      'target_type': 'message',
      'target_id': 'ana',
      'target_label': 'Ana: "oi"',
      'reason': 'spam',
      'status': 'open',
      'created_at': '2026-11-17T10:00:00Z',
    });
    expect(r.target, ReportTarget.message);
    expect(r.targetId, 'ana');
  });
}
