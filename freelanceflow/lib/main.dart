import 'dart:ui';
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

  // Fallback visual elegante para impedir a tela cinza com texto vermelho em Release
  ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
    return Material(
      color: AppColors.bgDark,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.warning, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Ocorreu uma falha visual',
                style: TextStyle(color: AppColors.textPrimaryDark, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tente recarregar a tela ou voltar para o início.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  };

  await SupabaseInit.initialize();
  runApp(const ProviderScope(child: FreelanceFlowApp()));
}

class FreelanceFlowApp extends ConsumerWidget {
  const FreelanceFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'FreelanceFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
