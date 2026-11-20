import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Plataforma em que o app está rodando, no formato gravado no banco.
String currentPlatformName() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.windows => 'windows',
    TargetPlatform.macOS => 'macos',
    _ => 'linux',
  };
}

/// Versão do app (`1.0.5+6`), ou null se não der para ler.
Future<String?> currentAppVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    if (info.version.isEmpty) return null;
    return info.buildNumber.isEmpty
        ? info.version
        : '${info.version}+${info.buildNumber}';
  } catch (_) {
    return null;
  }
}
