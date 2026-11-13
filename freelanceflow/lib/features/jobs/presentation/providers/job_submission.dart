import '../../../../core/services/attachment_store.dart';
import '../../../../core/services/storage_service.dart';
import '../../domain/entities/job.dart';

/// Arquivos do formulário da vaga: anexos mantidos, removidos e novos, e a
/// capa (nova, mantida ou a que estava salva antes da edição).
class JobFiles {
  final List<AppAttachment> kept;
  final List<AppAttachment> removed;
  final List<PickedFileData> added;
  final PickedFileData? newCover;
  final String? keptCoverUrl;
  final String? savedCoverUrl;

  const JobFiles({
    this.kept = const [],
    this.removed = const [],
    this.added = const [],
    this.newCover,
    this.keptCoverUrl,
    this.savedCoverUrl,
  });
}

/// Grava a vaga com [save] sem deixar arquivos órfãos: sobe a capa e os
/// anexos novos, grava e só então apaga o que foi removido ou trocado. Se
/// algo falhar antes de gravar, apaga o que subiu nesta tentativa e repassa
/// o erro (a vaga continua como estava).
Future<Job> saveJobWithFiles({
  required AttachmentStore store,
  required JobFiles files,
  required Future<Job> Function(
    List<Map<String, dynamic>> attachments,
    String? imageUrl,
  )
  save,
}) async {
  final cover = files.newCover == null
      ? null
      : await store.uploadFile(
          bucket: 'job_covers',
          folder: 'jobs',
          file: files.newCover!,
        );
  final Job saved;
  try {
    saved = await AttachmentSaveFlow(store).run(
      bucket: 'job_attachments',
      folder: 'jobs',
      newFiles: files.added,
      removed: files.removed,
      save: (uploaded) => save([
        for (final a in [...files.kept, ...uploaded]) a.toJson(),
      ], cover?.url ?? files.keptCoverUrl),
    );
  } catch (_) {
    if (cover != null) await store.deleteFiles([cover.url]);
    rethrow;
  }
  final oldCover = files.savedCoverUrl;
  if (oldCover != null && oldCover.isNotEmpty && oldCover != saved.imageUrl) {
    await store.deleteFiles([oldCover]);
  }
  return saved;
}
