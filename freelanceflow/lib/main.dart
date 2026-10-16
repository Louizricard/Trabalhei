import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/supabase_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Captura global de erros de renderização do Flutter
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('🚨 [FlutterError] ${details.exceptionAsString()}');
  };

  // Captura global de erros assíncronos não capturados
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🚨 [AsyncError] $error\n$stack');
    return true;
  };

  // Fallback visual elegante com Directionality explícita para prevenir erros recursivos
  ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: AppColors.bgDark,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.warning,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ocorreu uma falha visual',
                    style: TextStyle(
                      color: AppColors.textPrimaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    errorDetails.exceptionAsString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  };

  // Inicialização do Supabase
  try {
    await SupabaseInit.initialize();
  } catch (e, st) {
    debugPrint('🚨 [SupabaseInit] Erro ao inicializar Supabase: $e\n$st');
  }

  runApp(const ProviderScope(child: TrabalheiApp()));
}

class TrabalheiApp extends ConsumerWidget {
  const TrabalheiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Trabalhei',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
