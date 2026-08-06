import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/firebase_options.dart';
import 'core/config/supabase_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/presentation/providers/notification_provider.dart';
import 'features/notifications/presentation/services/notification_service.dart';

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
                  const Icon(Icons.error_outline_rounded, color: AppColors.warning, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Ocorreu uma falha visual',
                    style: TextStyle(color: AppColors.textPrimaryDark, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    errorDetails.exceptionAsString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
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
  await SupabaseInit.initialize();

  // Inicialização segura do Firebase e Push Notifications
  if (kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      }
      await NotificationService().initialize();
    } catch (e) {
      debugPrint('⚠️ [Firebase] Inicialização pendente ou não configurada: $e');
    }
  } else {
    // Plataformas desktop (Linux/Windows) utilizam notificações locais e realtime do Supabase
    await NotificationService().initialize();
  }

  runApp(const ProviderScope(child: TrabalheiApp()));
}

class TrabalheiApp extends ConsumerStatefulWidget {
  const TrabalheiApp({super.key});

  @override
  ConsumerState<TrabalheiApp> createState() => _TrabalheiAppState();
}

class _TrabalheiAppState extends ConsumerState<TrabalheiApp> {
  @override
  void initState() {
    super.initState();
    // Escuta eventos de navegação acionados por cliques em notificações push
    NotificationService().onNotificationNavigation.listen((route) {
      if (mounted && route.isNotEmpty) {
        try {
          ref.read(appRouterProvider).push(route);
        } catch (e) {
          debugPrint('🚨 [Navigation] Erro ao navegar para $route: $e');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Mantém o gerenciador de push tokens ativo e sincronizado com o ciclo de vida
    ref.watch(pushNotificationProvider);
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

