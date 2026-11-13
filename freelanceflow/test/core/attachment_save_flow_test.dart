import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/core/services/attachment_store.dart';

import '../helpers/memory_store.dart';

void main() {
  late MemoryStore store;
  late AttachmentSaveFlow flow;

  setUp(() {
    store = MemoryStore()..files.add('old');
    flow = AttachmentSaveFlow(store);
  });

  test('salva, envia os novos e apaga só depois os removidos', () async {
    final saved = await flow.run(
      bucket: 'b',
      folder: 'f',
      newFiles: [pickedFile('a.pdf'), pickedFile('b.pdf')],
      removed: [savedAttachment('old')],
      save: (uploaded) async => uploaded.length,
    );
    expect(saved, 2);
    expect(store.files, {'mem://b/f/a.pdf', 'mem://b/f/b.pdf'});
  });

  test('falha no 2º envio apaga o 1º e mantém os antigos', () async {
    store.failOn = 'b.pdf';
    var saved = false;
    await expectLater(
      flow.run(
        bucket: 'b',
        folder: 'f',
        newFiles: [pickedFile('a.pdf'), pickedFile('b.pdf')],
        removed: [savedAttachment('old')],
        save: (_) async => saved = true,
      ),
      throwsException,
    );
    expect(saved, isFalse);
    expect(store.files, {'old'});
  });

  test('falha ao salvar apaga os novos e mantém os antigos', () async {
    await expectLater(
      flow.run<void>(
        bucket: 'b',
        folder: 'f',
        newFiles: [pickedFile('a.pdf')],
        removed: [savedAttachment('old')],
        save: (_) async => throw Exception('banco fora'),
      ),
      throwsException,
    );
    expect(store.files, {'old'});
  });
}
