import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/supabase_client.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/platform/web_push.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../jobs/presentation/providers/job_alerts_provider.dart';
import '../../data/notification_preferences_repository.dart';
import '../../domain/entities/notification_category.dart';

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

/// Notificações e Alertas: onde a pessoa recebe os avisos (sempre no sino,
/// e também por e-mail e push), quais categorias chegam fora do app e os
/// alertas de vagas salvos.
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
      appBar: AppBar(title: const Text('Notificações e Alertas')),
      body: ResponsiveLayout(
        maxWidth: 640,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Os avisos sempre aparecem no sino do app. Escolha onde mais e quais avisos você quer receber.',
              style: TextStyle(color: AppColors.textSecondaryDark, height: 1.5),
            ),
            const SizedBox(height: 24),
            const _SectionHeader('Onde receber'),
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
            const SizedBox(height: 28),
            const _SectionHeader('O que avisar por e-mail e push'),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final c in NotificationCategory.values) ...[
                    if (c != NotificationCategory.values.first)
                      const Divider(height: 1, color: AppColors.borderDark),
                    SwitchListTile(
                      secondary: Icon(_categoryIcon(c)),
                      title: Text(c.label),
                      subtitle: Text(c.description),
                      value: prefs.valueOrNull?.isEnabled(c) ?? true,
                      onChanged: _busy || !prefs.hasValue
                          ? null
                          : (v) => _act(
                              () => repo.setCategoryEnabled(prefs.value!, c, v),
                            ),
                    ),
                  ],
                  const Divider(height: 1, color: AppColors.borderDark),
                  ListTile(
                    leading: const Icon(Icons.travel_explore_rounded),
                    title: const Text('Alertas de vagas'),
                    subtitle: Text(_alertsSummary(ref)),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMutedDark,
                    ),
                    onTap: () => context.push('/alerts'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _categoryIcon(NotificationCategory c) => switch (c) {
    NotificationCategory.messages => Icons.chat_bubble_outline_rounded,
    NotificationCategory.proposals => Icons.description_outlined,
    NotificationCategory.contracts => Icons.handshake_outlined,
    NotificationCategory.updates => Icons.campaign_outlined,
    NotificationCategory.opportunities => Icons.work_outline_rounded,
  };

  String _alertsSummary(WidgetRef ref) {
    final count = ref.watch(jobAlertsProvider).valueOrNull?.length;
    if (count == null || count == 0) {
      return 'Crie no mural, em Filtros > Salvar como alerta';
    }
    return count == 1 ? '1 alerta salvo' : '$count alertas salvos';
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

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.textMutedDark,
      ),
    ),
  );
}
