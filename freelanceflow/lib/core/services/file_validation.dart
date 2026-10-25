import 'dart:typed_data';
import '../errors/backend_errors.dart';

/// Confere o tipo real do arquivo pelos primeiros bytes, sem confiar na
/// extensão: um arquivo renomeado para .png não passa.
class FileValidation {
  FileValidation._();

  static const imageTypesLabel = 'JPG, PNG, WEBP ou GIF';

  /// Tipo da imagem (`image/png`...) ou null se não for uma imagem aceita.
  static String? imageMime(Uint8List bytes) {
    bool startsWith(List<int> sig, [int offset = 0]) =>
        bytes.length >= offset + sig.length &&
        List.generate(sig.length, (i) => bytes[offset + i]).join(',') ==
            sig.join(',');

    if (startsWith([0x89, 0x50, 0x4E, 0x47])) return 'image/png';
    if (startsWith([0xFF, 0xD8, 0xFF])) return 'image/jpeg';
    if (startsWith([0x47, 0x49, 0x46, 0x38])) return 'image/gif';
    if (startsWith([0x52, 0x49, 0x46, 0x46]) &&
        startsWith([0x57, 0x45, 0x42, 0x50], 8)) {
      return 'image/webp';
    }
    return null;
  }

  static bool isPdf(Uint8List bytes) =>
      bytes.length > 4 && String.fromCharCodes(bytes.sublist(0, 5)) == '%PDF-';

  /// Lança uma mensagem pronta para o usuário se o arquivo passar do limite.
  static void checkSize(int size, int maxBytes) {
    if (size > maxBytes) {
      final mb = (maxBytes / (1024 * 1024)).round();
      throw AppMessageException('O arquivo pode ter até $mb MB.');
    }
  }
}
