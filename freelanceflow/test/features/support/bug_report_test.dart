import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/core/errors/backend_errors.dart';
import 'package:trabalhei/features/support/domain/entities/bug_report.dart';
import 'package:trabalhei/features/support/domain/repositories/bug_report_repository.dart';
import 'package:trabalhei/features/support/presentation/providers/bug_report_controller.dart';
import 'package:trabalhei/features/support/presentation/widgets/bug_report_sheet.dart';

class _FakeRepo implements BugReportRepository {
  final sent = <BugReport>[];
  Completer<void>? gate;
  Object? failWith;

  @override
  Future<void> submit(BugReport report) async {
    sent.add(report);
    if (gate != null) await gate!.future;
    if (failWith != null) throw failWith!;
  }
}

ProviderContainer _container(_FakeRepo repo) => ProviderContainer(
  overrides: [
    bugReportRepositoryProvider.overrideWithValue(repo),
    appVersionProvider.overrideWith((_) async => '1.0.5+6'),
  ],
);

void main() {
  group('BugReportRules', () {
    test('descrição obrigatória, com mínimo e máximo', () {
      expect(BugReportRules.validateDescription(''), isNotNull);
      expect(BugReportRules.validateDescription('   curto  '), isNotNull);
      expect(BugReportRules.validateDescription('x' * 4001), isNotNull);
      expect(
        BugReportRules.validateDescription('O botão de enviar não responde'),
        isNull,
      );
    });

    test('captura só em PNG, JPG ou WEBP e até 5 MB', () {
      expect(BugReportRules.validateScreenshot('image/png', 1000), isNull);
      expect(BugReportRules.validateScreenshot('image/webp', 1000), isNull);
      expect(BugReportRules.validateScreenshot('image/gif', 1000), isNotNull);
      expect(
        BugReportRules.validateScreenshot('image/jpeg', 6 * 1024 * 1024),
        isNotNull,
      );
    });

    test('extensão da captura segue o tipo real', () {
      final bytes = Uint8List(0);
      expect(
        BugScreenshot(bytes: bytes, mimeType: 'image/png').extension,
        'png',
      );
      expect(
        BugScreenshot(bytes: bytes, mimeType: 'image/jpeg').extension,
        'jpg',
      );
    });
  });

  group('BugReportController', () {
    test('envia com plataforma e versão do app', () async {
      final repo = _FakeRepo();
      final c = _container(repo);
      addTearDown(c.dispose);
      final sub = c.listen(bugReportControllerProvider, (_, _) {});
      addTearDown(sub.close);

      final ok = await c
          .read(bugReportControllerProvider.notifier)
          .submit(description: 'O chat não carrega as mensagens antigas');

      expect(ok, isTrue);
      expect(repo.sent.single.appVersion, '1.0.5+6');
      expect(repo.sent.single.platform, isNotEmpty);
    });

    test(
      'ignora um segundo envio enquanto o primeiro está em andamento',
      () async {
        final repo = _FakeRepo()..gate = Completer<void>();
        final c = _container(repo);
        addTearDown(c.dispose);
        final sub = c.listen(bugReportControllerProvider, (_, _) {});
        addTearDown(sub.close);
        final notifier = c.read(bugReportControllerProvider.notifier);

        final first = notifier.submit(description: 'Primeiro relatório de bug');
        final second = await notifier.submit(
          description: 'Clique repetido aqui',
        );
        repo.gate!.complete();

        expect(second, isFalse);
        expect(await first, isTrue);
        expect(repo.sent, hasLength(1));
      },
    );

    test('erro do backend volta para a tela e libera novo envio', () async {
      final repo = _FakeRepo()..failWith = const AppMessageException('Falhou');
      final c = _container(repo);
      addTearDown(c.dispose);
      final sub = c.listen(bugReportControllerProvider, (_, _) {});
      addTearDown(sub.close);
      final notifier = c.read(bugReportControllerProvider.notifier);

      await expectLater(
        notifier.submit(description: 'Relatório que vai falhar'),
        throwsA(isA<AppMessageException>()),
      );
      expect(c.read(bugReportControllerProvider).hasError, isTrue);

      repo.failWith = null;
      expect(
        await notifier.submit(description: 'Agora o envio funciona'),
        isTrue,
      );
    });
  });

  group('BugReportSheet', () {
    Future<_FakeRepo> pump(WidgetTester tester) async {
      final repo = _FakeRepo();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bugReportRepositoryProvider.overrideWithValue(repo),
            appVersionProvider.overrideWith((_) async => '1.0.5+6'),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showBugReportSheet(context),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('não envia sem descrição', (tester) async {
      final repo = await pump(tester);
      await tester.tap(find.text('Enviar relatório'));
      await tester.pump();
      expect(find.text('Descreva o problema.'), findsOneWidget);
      expect(repo.sent, isEmpty);
    });

    testWidgets('envia, fecha e confirma', (tester) async {
      final repo = await pump(tester);
      await tester.enterText(
        find.byType(TextFormField),
        'A lista de vagas some ao trocar de aba',
      );
      await tester.tap(find.text('Enviar relatório'));
      await tester.pumpAndSettle();

      expect(repo.sent, hasLength(1));
      expect(find.text('Enviar relatório'), findsNothing);
      expect(find.textContaining('Relatório enviado'), findsOneWidget);
    });

    testWidgets('erro mantém o formulário aberto e avisa', (tester) async {
      final repo = await pump(tester);
      repo.failWith = const AppMessageException('Sem conexão');
      await tester.enterText(
        find.byType(TextFormField),
        'Não consigo anexar o arquivo da proposta',
      );
      await tester.tap(find.text('Enviar relatório'));
      await tester.pumpAndSettle();

      expect(find.text('Enviar relatório'), findsOneWidget);
      expect(find.textContaining('Sem conexão'), findsOneWidget);
    });
  });
}
