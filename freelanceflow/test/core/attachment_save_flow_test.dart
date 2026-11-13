import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/core/services/attachment_store.dart';
import 'package:trabalhei/core/services/storage_service.dart';

class _MemoryStore implements AttachmentStore {
  final Set<String> files = {};
  String? failOn;

  @override
  Future<AppAttachment> uploadFile({
    required String bucket,
    required String folder,
    required PickedFileData file,
  }) async {
    if (file.name == failOn) throw Exception('falhou ${file.name}');
    final url = 'mem://$bucket/$folder/${file.name}';
    files.add(url);
    return AppAttachment(
      id: file.name,
      name: file.name,
      url: url,
      size: file.size,
      mimeType: file.mimeType,
    );
  }

  @override
  Future<void> deleteFiles(Iterable<String> urls) async =>
      files.removeAll(urls.toList());
}

PickedFileData _file(String name) => PickedFileData(
  name: name,
  bytes: Uint8List(1),
  size: 1,
  mimeType: 'application/pdf',
);

AppAttachment _existing(String url) =>
    AppAttachment(id: url, name: url, url: url, size: 1, mimeType: 'x');

void main() {
  late _MemoryStore store;
  late AttachmentSaveFlow flow;

  setUp(() {
    store = _MemoryStore()..files.add('old');
    flow = AttachmentSaveFlow(store);
  });

  test('salva, envia os novos e apaga só depois os removidos', () async {
    final saved = await flow.run(
      bucket: 'b',
      folder: 'f',
      newFiles: [_file('a.pdf'), _file('b.pdf')],
      removed: [_existing('old')],
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
        newFiles: [_file('a.pdf'), _file('b.pdf')],
        removed: [_existing('old')],
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
        newFiles: [_file('a.pdf')],
        removed: [_existing('old')],
        save: (_) async => throw Exception('banco fora'),
      ),
      throwsException,
    );
    expect(store.files, {'old'});
  });
}
