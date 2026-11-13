import 'dart:typed_data';

import 'package:trabalhei/core/services/attachment_store.dart';
import 'package:trabalhei/core/services/storage_service.dart';

/// Storage em memória para testar fluxos de anexos sem rede.
class MemoryStore implements AttachmentStore {
  final Set<String> files = {};

  /// Nome do arquivo cujo envio falha.
  String? failOn;

  /// Simula a Storage API fora do ar na exclusão (melhor esforço: não lança).
  bool deleteFails = false;

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
  Future<void> deleteFiles(Iterable<String> urls) async {
    if (!deleteFails) files.removeAll(urls.toList());
  }
}

PickedFileData pickedFile(String name) => PickedFileData(
  name: name,
  bytes: Uint8List(1),
  size: 1,
  mimeType: 'application/pdf',
);

AppAttachment savedAttachment(String url) =>
    AppAttachment(id: url, name: url, url: url, size: 1, mimeType: 'x');
