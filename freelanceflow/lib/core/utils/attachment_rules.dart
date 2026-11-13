/// Regras de seleção de anexos, independentes de tela: extensão, tamanho,
/// quantidade e duplicidade. A tela mostra os motivos de recusa de uma vez,
/// em vez de um aviso por arquivo.
library;

/// Extensões aceitas por padrão em vagas, propostas e entregas.
const defaultAttachmentExtensions = [
  'pdf',
  'doc',
  'docx',
  'png',
  'jpg',
  'jpeg',
  'webp',
  'zip',
  'txt',
];

String fileExtension(String name) {
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
}

String formatBytes(int size) {
  if (size < 1024) return '$size B';
  if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
  return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class AttachmentSelection<T> {
  final List<T> accepted;
  final List<String> wrongType;
  final List<String> tooBig;
  final List<String> duplicated;
  final List<String> overLimit;

  const AttachmentSelection({
    required this.accepted,
    this.wrongType = const [],
    this.tooBig = const [],
    this.duplicated = const [],
    this.overLimit = const [],
  });

  bool get hasRejections =>
      wrongType.isNotEmpty ||
      tooBig.isNotEmpty ||
      duplicated.isNotEmpty ||
      overLimit.isNotEmpty;

  /// Uma frase por motivo, para um único aviso.
  List<String> messages({
    required int limitBytes,
    required int maxFiles,
    required List<String> extensions,
  }) => [
    if (wrongType.isNotEmpty)
      '${wrongType.join(', ')}: tipo não aceito '
          '(use ${extensions.map((e) => e.toUpperCase()).join(', ')}).',
    if (tooBig.isNotEmpty)
      '${tooBig.join(', ')}: passa de ${formatBytes(limitBytes)} por arquivo.',
    if (duplicated.isNotEmpty) '${duplicated.join(', ')}: já está na lista.',
    if (overLimit.isNotEmpty)
      '${overLimit.join(', ')}: ficou de fora (máximo de $maxFiles arquivos).',
  ];
}

/// Separa os arquivos escolhidos entre aceitos e recusados.
AttachmentSelection<T> selectAttachments<T>({
  required List<T> picked,
  required String Function(T) nameOf,
  required int Function(T) sizeOf,
  required Iterable<String> currentNames,
  required int remainingSlots,
  required int limitBytes,
  List<String> extensions = defaultAttachmentExtensions,
}) {
  final names = currentNames.map((n) => n.toLowerCase()).toSet();
  final accepted = <T>[];
  final wrongType = <String>[], tooBig = <String>[];
  final duplicated = <String>[], overLimit = <String>[];
  for (final file in picked) {
    final name = nameOf(file);
    if (!extensions.contains(fileExtension(name))) {
      wrongType.add(name);
    } else if (sizeOf(file) > limitBytes) {
      tooBig.add(name);
    } else if (!names.add(name.toLowerCase())) {
      duplicated.add(name);
    } else if (accepted.length >= remainingSlots) {
      overLimit.add(name);
    } else {
      accepted.add(file);
    }
  }
  return AttachmentSelection(
    accepted: accepted,
    wrongType: wrongType,
    tooBig: tooBig,
    duplicated: duplicated,
    overLimit: overLimit,
  );
}
