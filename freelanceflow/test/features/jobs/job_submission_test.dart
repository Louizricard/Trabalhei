import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/features/jobs/domain/entities/job.dart';
import 'package:trabalhei/features/jobs/presentation/providers/job_submission.dart';

import '../../helpers/memory_store.dart';

/// Edição de vaga com anexos: o storage e a vaga terminam consistentes
/// mesmo quando o envio, a gravação ou a exclusão falham.
void main() {
  late MemoryStore store;
  List<Map<String, dynamic>>? savedAttachments;
  String? savedCover;

  Future<Job> save(
    List<Map<String, dynamic>> attachments,
    String? cover,
  ) async {
    savedAttachments = attachments;
    savedCover = cover;
    return Job(
      id: 'j1',
      clientId: 'c1',
      clientName: 'Cliente',
      title: 'Vaga',
      category: 'Design',
      description: 'Descrição',
      budgetMin: 1,
      budgetMax: 2,
      attachments: attachments,
      imageUrl: cover,
      createdAt: DateTime(2026),
    );
  }

  Future<Never> failSave(List<Map<String, dynamic>> a, String? c) =>
      Future.error(Exception('rede'));

  setUp(() {
    store = MemoryStore()..files.addAll({'old.pdf', 'keep.pdf', 'cover.png'});
    savedAttachments = null;
    savedCover = null;
  });

  JobFiles editFiles() => JobFiles(
    kept: [savedAttachment('keep.pdf')],
    removed: [savedAttachment('old.pdf')],
    added: [pickedFile('a.pdf'), pickedFile('b.pdf')],
    newCover: pickedFile('nova.png'),
    savedCoverUrl: 'cover.png',
  );

  test('salva mantidos + novos, troca a capa e apaga o que saiu', () async {
    await saveJobWithFiles(store: store, files: editFiles(), save: save);
    expect(savedAttachments!.map((a) => a['url']), [
      'keep.pdf',
      'mem://job_attachments/jobs/a.pdf',
      'mem://job_attachments/jobs/b.pdf',
    ]);
    expect(savedCover, 'mem://job_covers/jobs/nova.png');
    expect(store.files, isNot(contains('old.pdf')));
    expect(store.files, isNot(contains('cover.png')));
    expect(store.files, contains('keep.pdf'));
  });

  test('falha no 2º arquivo: nada é gravado nem fica órfão', () async {
    store.failOn = 'b.pdf';
    await expectLater(
      saveJobWithFiles(store: store, files: editFiles(), save: save),
      throwsException,
    );
    expect(savedAttachments, isNull);
    expect(store.files, {'old.pdf', 'keep.pdf', 'cover.png'});
  });

  test('falha ao gravar: apaga os novos e mantém os antigos', () async {
    await expectLater(
      saveJobWithFiles(store: store, files: editFiles(), save: failSave),
      throwsException,
    );
    expect(store.files, {'old.pdf', 'keep.pdf', 'cover.png'});
  });

  test('falha ao apagar não desfaz a vaga salva (fica para a fila)', () async {
    store.deleteFails = true;
    final job = await saveJobWithFiles(
      store: store,
      files: editFiles(),
      save: save,
    );
    expect(job.attachments, hasLength(3));
    expect(store.files, containsAll(['old.pdf', 'cover.png']));
  });

  test('manter a capa não apaga a capa', () async {
    await saveJobWithFiles(
      store: store,
      files: const JobFiles(
        keptCoverUrl: 'cover.png',
        savedCoverUrl: 'cover.png',
      ),
      save: save,
    );
    expect(savedCover, 'cover.png');
    expect(store.files, contains('cover.png'));
  });
}
