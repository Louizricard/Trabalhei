import 'dart:typed_data';

/// Captura de tela anexada a um relatório de bug.
class BugScreenshot {
  final Uint8List bytes;
  final String mimeType;

  const BugScreenshot({required this.bytes, required this.mimeType});

  String get extension => switch (mimeType) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => 'jpg',
  };
}

/// Relatório pronto para enviar. Data e autor são gravados pelo banco.
class BugReport {
  final String description;
  final BugScreenshot? screenshot;
  final String platform;
  final String? appVersion;

  const BugReport({
    required this.description,
    required this.platform,
    this.screenshot,
    this.appVersion,
  });
}

/// Regras do formulário, as mesmas conferidas pelo banco.
class BugReportRules {
  BugReportRules._();

  static const minDescription = 10;
  static const maxDescription = 4000;
  static const maxScreenshotBytes = 5 * 1024 * 1024;
  static const screenshotTypes = {'image/png', 'image/jpeg', 'image/webp'};
  static const screenshotTypesLabel = 'PNG, JPG ou WEBP';

  /// Mensagem de erro da descrição, ou null se estiver boa.
  static String? validateDescription(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Descreva o problema.';
    if (text.length < minDescription) {
      return 'Conte um pouco mais (mínimo de $minDescription caracteres).';
    }
    if (text.length > maxDescription) {
      return 'Use no máximo $maxDescription caracteres.';
    }
    return null;
  }

  /// Mensagem de erro da imagem, ou null se for aceita.
  static String? validateScreenshot(String mimeType, int size) {
    if (!screenshotTypes.contains(mimeType)) {
      return 'Envie a captura em $screenshotTypesLabel.';
    }
    if (size > maxScreenshotBytes) return 'A imagem pode ter até 5 MB.';
    return null;
  }
}
