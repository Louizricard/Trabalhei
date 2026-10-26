import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../domain/admin_models.dart';
import '../providers/admin_provider.dart';

/// Painel de moderação: denúncias, usuários (suspender/reativar) e vagas
/// (remover do mural). Só abre para administradores.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    return isAdmin.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const _NotAllowed(),
      data: (ok) => ok ? const _AdminTabs() : const _NotAllowed(),
    );
  }
}

class _NotAllowed extends StatelessWidget {
  const _NotAllowed();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Moderação')),
    body: const EmptyStateWidget(
      icon: Icons.lock_outline_rounded,
      title: 'Acesso restrito',
      description: 'Esta área é só para a equipe de moderação.',
    ),
  );
}

class _AdminTabs extends ConsumerWidget {
  const _AdminTabs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(adminOverviewProvider).valueOrNull;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Moderação'),
          actions: [
            IconButton(
              tooltip: 'Atualizar',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _refreshAll(ref),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(
                text: overview == null || overview.openReports == 0
                    ? 'Denúncias'
                    : 'Denúncias (${overview.openReports})',
              ),
              const Tab(text: 'Usuários'),
              const Tab(text: 'Vagas'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (overview != null) _OverviewRow(overview: overview),
            const Expanded(
              child: TabBarView(
                children: [_ReportsTab(), _UsersTab(), _JobsTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _refreshAll(WidgetRef ref) {
  ref.invalidate(adminOverviewProvider);
  ref.invalidate(adminReportsProvider);
  ref.invalidate(adminUsersProvider);
  ref.invalidate(adminJobsProvider);
}

/// Executa uma ação de moderação com aviso de sucesso ou erro.
Future<void> _run(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action,
  String done,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    _refreshAll(ref);
    messenger.showSnackBar(
      SnackBar(content: Text(done), backgroundColor: AppColors.success),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(friendlyError(e)),
        backgroundColor: AppColors.error,
      ),
    );
  }
}

/// Pede o motivo (obrigatório), que vai para o registro e para o aviso à pessoa.
Future<String?> _askReason(BuildContext context, String title) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            maxLength: 300,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Motivo',
              hintText: 'A pessoa recebe este motivo no aviso',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: controller.text.trim().isEmpty
                ? null
                : () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ),
  ).whenComplete(controller.dispose);
}

Future<void> _suspend(
  BuildContext context,
  WidgetRef ref,
  String userId,
) async {
  final reason = await _askReason(context, 'Suspender conta');
  if (reason == null || !context.mounted) return;
  await _run(
    context,
    ref,
    () => ref.read(adminRepositoryProvider).suspendUser(userId, reason),
    'Conta suspensa. As vagas abertas dela foram encerradas.',
  );
}

Future<void> _removeJob(
  BuildContext context,
  WidgetRef ref,
  String jobId,
) async {
  final reason = await _askReason(context, 'Remover vaga do mural');
  if (reason == null || !context.mounted) return;
  await _run(
    context,
    ref,
    () => ref.read(adminRepositoryProvider).removeJob(jobId, reason),
    'Vaga removida. O cliente foi avisado.',
  );
}

class _OverviewRow extends StatelessWidget {
  final AdminOverview overview;
  const _OverviewRow({required this.overview});

  @override
  Widget build(BuildContext context) {
    Widget item(String label, int value, {Color? color}) => Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color ?? AppColors.textPrimaryDark,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMutedDark,
            ),
          ),
        ],
      ),
    );
    return ResponsiveLayout(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              item('Usuários', overview.users),
              item('Suspensas', overview.suspended),
              item('Vagas abertas', overview.openJobs),
              item(
                'Denúncias abertas',
                overview.openReports,
                color: overview.openReports > 0 ? AppColors.warning : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Denúncias
class _ReportsTab extends ConsumerStatefulWidget {
  const _ReportsTab();

  @override
  ConsumerState<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<_ReportsTab> {
  String _status = 'open';

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(adminReportsProvider(_status));
    return ResponsiveLayout(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'open', label: Text('Abertas')),
                ButtonSegment(value: 'resolved', label: Text('Resolvidas')),
                ButtonSegment(value: 'dismissed', label: Text('Descartadas')),
              ],
              selected: {_status},
              onSelectionChanged: (s) => setState(() => _status = s.first),
            ),
          ),
          Expanded(
            child: reports.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyStateWidget(
                icon: Icons.error_outline_rounded,
                title: 'Erro ao carregar denúncias',
                description: friendlyError(e),
              ),
              data: (list) => list.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.verified_user_outlined,
                      title: 'Nenhuma denúncia aqui',
                      description:
                          'Quando alguém denunciar uma vaga ou perfil, aparece nesta lista.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _ReportCard(report: list[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends ConsumerWidget {
  final AdminReport report;
  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isJob = report.target == ReportTarget.job;
    final open = report.status == 'open';
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isJob
                    ? Icons.work_outline_rounded
                    : Icons.person_outline_rounded,
                size: 18,
                color: AppColors.textSecondaryDark,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${isJob ? 'Vaga' : 'Perfil'}: ${report.targetLabel ?? '(removido)'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (report.reportsOnTarget > 1)
                _Badge(
                  '${report.reportsOnTarget} denúncias',
                  AppColors.warning,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            report.reason.label,
            style: const TextStyle(
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (report.details?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              report.details!,
              style: const TextStyle(color: AppColors.textSecondaryDark),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Por ${report.reporterName ?? 'usuário removido'} · ${DateFormatter.relativeTime(report.createdAt)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMutedDark,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Ver'),
                onPressed: () => context.push(
                  isJob
                      ? '/jobs/${report.targetId}'
                      : '/profile/${report.targetId}',
                ),
              ),
              if (open) ...[
                TextButton(
                  onPressed: () => _run(
                    context,
                    ref,
                    () => ref
                        .read(adminRepositoryProvider)
                        .resolveReport(report.id, dismiss: true),
                    'Denúncia descartada.',
                  ),
                  child: const Text('Descartar'),
                ),
                TextButton(
                  onPressed: () => _run(
                    context,
                    ref,
                    () => ref
                        .read(adminRepositoryProvider)
                        .resolveReport(report.id, dismiss: false),
                    'Denúncia marcada como resolvida.',
                  ),
                  child: const Text('Resolver'),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  onPressed: () => isJob
                      ? _removeJob(context, ref, report.targetId)
                      : _suspend(context, ref, report.targetId),
                  child: Text(isJob ? 'Remover vaga' : 'Suspender conta'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Usuários
class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(adminUsersProvider(_query));
    return ResponsiveLayout(
      child: Column(
        children: [
          _SearchField(
            hint: 'Buscar por nome ou e-mail',
            onSubmitted: (q) => setState(() => _query = q.trim()),
          ),
          Expanded(
            child: users.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyStateWidget(
                icon: Icons.error_outline_rounded,
                title: 'Erro ao carregar usuários',
                description: friendlyError(e),
              ),
              data: (list) => list.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.person_search_rounded,
                      title: 'Ninguém encontrado',
                      description: 'Tente outro nome ou e-mail.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _UserTile(user: list[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends ConsumerWidget {
  final AdminUser user;
  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = user.role == 'client' ? 'Contratante' : 'Freelancer';
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => context.push('/profile/${user.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        user.fullName.isEmpty ? '(sem nome)' : user.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (user.isAdmin) const _Badge('Admin', AppColors.info),
                      if (user.isSuspended)
                        const _Badge('Suspensa', AppColors.error),
                      if (user.openReports > 0)
                        _Badge(
                          '${user.openReports} denúncias',
                          AppColors.warning,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                  Text(
                    '$role · ${user.plan == 'pro' ? 'Pro' : 'Grátis'} · desde ${DateFormatter.simpleDate(user.createdAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMutedDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!user.isAdmin)
            user.isSuspended
                ? TextButton(
                    onPressed: () => _run(
                      context,
                      ref,
                      () => ref
                          .read(adminRepositoryProvider)
                          .unsuspendUser(user.id),
                      'Conta reativada.',
                    ),
                    child: const Text('Reativar'),
                  )
                : TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    onPressed: () => _suspend(context, ref, user.id),
                    child: const Text('Suspender'),
                  ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Vagas
class _JobsTab extends ConsumerStatefulWidget {
  const _JobsTab();

  @override
  ConsumerState<_JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends ConsumerState<_JobsTab> {
  String _query = '';

  static const _statusLabels = {
    'open': 'Aberta',
    'in_progress': 'Em andamento',
    'completed': 'Concluída',
    'cancelled': 'Cancelada',
  };

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(adminJobsProvider(_query));
    return ResponsiveLayout(
      child: Column(
        children: [
          _SearchField(
            hint: 'Buscar por título ou cliente',
            onSubmitted: (q) => setState(() => _query = q.trim()),
          ),
          Expanded(
            child: jobs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyStateWidget(
                icon: Icons.error_outline_rounded,
                title: 'Erro ao carregar vagas',
                description: friendlyError(e),
              ),
              data: (list) => list.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.work_off_outlined,
                      title: 'Nenhuma vaga encontrada',
                      description: 'Tente outro título ou cliente.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final job = list[i];
                        return GlassCard(
                          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => context.push('/jobs/${job.id}'),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            job.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (job.openReports > 0)
                                            _Badge(
                                              '${job.openReports} denúncias',
                                              AppColors.warning,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${job.clientName ?? 'Cliente'} · ${_statusLabels[job.status] ?? job.status} · ${DateFormatter.relativeTime(job.createdAt)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMutedDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (job.status == 'open')
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                  ),
                                  onPressed: () =>
                                      _removeJob(context, ref, job.id),
                                  child: const Text('Remover'),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onSubmitted;
  const _SearchField({required this.hint, required this.onSubmitted});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: TextField(
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withAlpha(40),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withAlpha(120)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
    ),
  );
}
