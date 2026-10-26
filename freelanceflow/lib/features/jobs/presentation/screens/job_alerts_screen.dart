import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../domain/entities/job_alert.dart';
import '../providers/job_alerts_provider.dart';

/// Alertas de vagas salvos: ligar, desligar e apagar.
class JobAlertsScreen extends ConsumerWidget {
  const JobAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(jobAlertsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Alertas de vagas')),
      body: ResponsiveLayout(
        maxWidth: 720,
        child: alerts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyStateWidget(
            icon: Icons.error_outline_rounded,
            title: 'Erro ao carregar alertas',
            description: friendlyError(e),
          ),
          data: (list) => list.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.notifications_none_rounded,
                  title: 'Nenhum alerta ainda',
                  description:
                      'No mural, busque e filtre as vagas do seu jeito e toque em Filtros > Salvar como alerta. Avisamos quando sair uma vaga compatível.',
                  actionText: 'Ir para o mural',
                  onAction: () => context.go('/jobs'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => i == list.length
                      ? Text(
                          'Até 10 alertas. Os avisos chegam no sino do app, por e-mail e por push, conforme Perfil > Notificações.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMutedDark,
                          ),
                        )
                      : _AlertCard(alert: list[i]),
                ),
        ),
      ),
    );
  }
}

class _AlertCard extends ConsumerWidget {
  final JobAlert alert;
  const _AlertCard({required this.alert});

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
    ref.invalidate(jobAlertsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(jobAlertRepositoryProvider);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.describe(),
                    style: const TextStyle(color: AppColors.textSecondaryDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.lastMatchedAt == null
                        ? 'Nenhuma vaga compatível ainda'
                        : 'Última vaga compatível ${DateFormatter.relativeTime(alert.lastMatchedAt!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMutedDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Switch(
            value: alert.isActive,
            onChanged: (v) =>
                _run(context, ref, () => repo.setActive(alert.id, v)),
          ),
          IconButton(
            tooltip: 'Apagar alerta',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _run(context, ref, () => repo.delete(alert.id)),
          ),
        ],
      ),
    );
  }
}
