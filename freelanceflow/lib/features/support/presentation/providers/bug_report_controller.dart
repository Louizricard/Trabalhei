import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_client.dart';
import '../../../../core/platform/app_info.dart';
import '../../data/bug_report_repository_impl.dart';
import '../../domain/entities/bug_report.dart';
import '../../domain/repositories/bug_report_repository.dart';

final bugReportRepositoryProvider = Provider<BugReportRepository>(
  (ref) => BugReportRepositoryImpl(ref.watch(supabaseClientProvider)),
);

/// Versão do app para o relatório (null se indisponível).
final appVersionProvider = FutureProvider<String?>(
  (ref) => currentAppVersion(),
);

/// Envio do relatório. Enquanto um envio está em andamento, outro é ignorado.
class BugReportController extends AutoDisposeAsyncNotifier<void> {
  bool _sending = false;

  // Síncrono: o formulário abre já pronto para enviar, sem estado de carga.
  @override
  FutureOr<void> build() {}

  /// `true` se enviou; `false` se já havia um envio em andamento.
  /// Erros ficam no estado e também são relançados para a tela avisar.
  Future<bool> submit({
    required String description,
    BugScreenshot? screenshot,
  }) async {
    if (_sending) return false;
    _sending = true;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final version = await ref.read(appVersionProvider.future);
      await ref
          .read(bugReportRepositoryProvider)
          .submit(
            BugReport(
              description: description,
              screenshot: screenshot,
              platform: currentPlatformName(),
              appVersion: version,
            ),
          );
    });
    _sending = false;
    state = result;
    if (result case AsyncError(:final error, :final stackTrace)) {
      Error.throwWithStackTrace(error, stackTrace);
    }
    return true;
  }
}

final bugReportControllerProvider =
    AsyncNotifierProvider.autoDispose<BugReportController, void>(
      BugReportController.new,
    );
