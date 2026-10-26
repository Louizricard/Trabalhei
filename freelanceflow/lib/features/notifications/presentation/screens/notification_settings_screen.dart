import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_client.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/platform/web_push.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../data/notification_preferences_repository.dart';

final notificationPreferencesRepositoryProvider =
    Provider<NotificationPreferencesRepository>(
      (ref) =>
          NotificationPreferencesRepository(ref.watch(supabaseClientProvider)),
    );

final notificationPreferencesProvider =
    FutureProvider.autoDispose<NotificationPreferences>(
      (ref) => ref.watch(notificationPreferencesRepositoryProvider).load(),
    );

final pushActiveHereProvider = FutureProvider.autoDispose<bool>(
  (ref) =>
      ref.watch(notificationPreferencesRepositoryProvider).isPushActiveHere(),
);

/// Onde a pessoa recebe os avisos: sempre no app, e também por e-mail e push.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _busy = false;

  Future<void> _act(Future<void> Function() action, [String? done]) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (done != null) {
        messenger.showSnackBar(
          SnackBar(content: Text(done), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(friendlyError(e)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      ref.invalidate(notificationPreferencesProvider);
      ref.invalidate(pushActiveHereProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(notificationPreferencesRepositoryProvider);
    final prefs = ref.watch(notificationPreferencesProvider);
    final pushHere = ref.watch(pushActiveHereProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: ResponsiveLayout(
        maxWidth: 640,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Os avisos sempre aparecem no sino do app. Escolha onde mais você quer recebê-los.',
              style: TextStyle(color: AppColors.textSecondaryDark, height: 1.5),
            ),
            const SizedBox(height: 20),
            GlassCard(
              padding: EdgeInsets.zero,
              child: SwitchListTile(
                secondary: const Icon(Icons.mail_outline_rounded),
                title: const Text('Por e-mail'),
                subtitle: const Text(
                  'Propostas, contratos, entregas, mensagens e alertas de vagas.',
                ),
                value: prefs.valueOrNull?.emailEnabled ?? true,
                onChanged: _busy || !prefs.hasValue
                    ? null
                    : (v) => _act(
                        () => repo.setEmailEnabled(v),
                        v ? 'E-mails ativados.' : 'E-mails desativados.',
                      ),
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.notifications_active_outlined),
                      SizedBox(width: 12),
                      Text(
                        'Push neste navegador',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._pushSection(repo, pushHere),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _pushSection(
    NotificationPreferencesRepository repo,
    bool active,
  ) {
    Widget note(String text) => Text(
      text,
      style: const TextStyle(color: AppColors.textSecondaryDark, height: 1.5),
    );
    if (!kIsWeb) {
      return [
        note(
          'No app para Android e Windows, os avisos aparecem no sino enquanto o app está aberto. '
          'Para receber com o app fechado, ative o push na versão web (trabalhei.site/app) ou use o e-mail.',
        ),
      ];
    }
    if (!webPushSupported) {
      return [
        note(
          'Este navegador não recebe notificações push. No iPhone, abra o Trabalhei no Safari, '
          'toque em Compartilhar > Adicionar à Tela de Início e ative por lá.',
        ),
      ];
    }
    if (webPushPermission == 'denied') {
      return [
        note(
          'As notificações estão bloqueadas para este site. Libere nas configurações do navegador '
          '(cadeado ao lado do endereço > Notificações) e volte aqui.',
        ),
      ];
    }
    return [
      note(
        active
            ? 'Ativo: você recebe os avisos neste navegador mesmo com o Trabalhei fechado.'
            : 'Receba os avisos neste navegador mesmo com o Trabalhei fechado.',
      ),
      const SizedBox(height: 12),
      active
          ? OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _act(
                      repo.disablePushHere,
                      'Push desativado neste navegador.',
                    ),
              child: const Text('Desativar neste navegador'),
            )
          : FilledButton(
              onPressed: _busy
                  ? null
                  : () => _act(() async {
                      if (!await repo.enablePushHere()) {
                        throw const AppMessageException(
                          'Permissão negada. Para ativar, libere as notificações deste site no navegador.',
                        );
                      }
                    }, 'Push ativado. Você vai receber os avisos neste navegador.'),
              child: const Text('Ativar notificações push'),
            ),
    ];
  }
}
