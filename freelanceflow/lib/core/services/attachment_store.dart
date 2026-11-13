import 'storage_service.dart';

/// Onde os anexos ficam guardados. Implementado por [StorageService]; nos
/// testes, por um armazenamento em memória.
abstract interface class AttachmentStore {
  /// Envia o arquivo e devolve o anexo pronto para gravar no registro.
  /// Lança uma exceção com mensagem amigável quando o envio falha.
  Future<AppAttachment> uploadFile({
    required String bucket,
    required String folder,
    required PickedFileData file,
  });

  /// Apaga os arquivos sem lançar exceção (melhor esforço).
  Future<void> deleteFiles(Iterable<String> urls);
}

/// Salva um registro com anexos sem deixar arquivos órfãos nem registros
/// apontando para arquivos que não existem:
///
/// 1. envia os arquivos novos; se um falhar, apaga os que já tinham subido
///    nesta tentativa e repassa o erro (o formulário continua preenchido);
/// 2. grava o registro com [save]; se falhar, apaga os arquivos novos;
/// 3. só depois do registro salvo, apaga os anexos que a pessoa removeu.
///
/// O que não puder ser apagado no passo 1, 2 ou 3 fica para a limpeza do
/// servidor, que encontra arquivos sem referência.
class AttachmentSaveFlow {
  final AttachmentStore store;

  const AttachmentSaveFlow(this.store);

  Future<T> run<T>({
    required String bucket,
    required String folder,
    required List<PickedFileData> newFiles,
    List<AppAttachment> removed = const [],
    required Future<T> Function(List<AppAttachment> uploaded) save,
  }) async {
    final uploaded = <AppAttachment>[];
    try {
      for (final file in newFiles) {
        uploaded.add(
          await store.uploadFile(bucket: bucket, folder: folder, file: file),
        );
      }
    } catch (_) {
      await store.deleteFiles(uploaded.map((a) => a.url));
      rethrow;
    }
    final T result;
    try {
      result = await save(uploaded);
    } catch (_) {
      await store.deleteFiles(uploaded.map((a) => a.url));
      rethrow;
    }
    if (removed.isNotEmpty) {
      await store.deleteFiles(removed.map((a) => a.url));
    }
    return result;
  }
}
