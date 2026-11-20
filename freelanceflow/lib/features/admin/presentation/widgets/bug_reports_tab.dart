import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../domain/admin_models.dart';
import '../providers/admin_provider.dart';

/// Relatórios de bug enviados pelo Perfil: abertos e resolvidos.
class BugReportsTab extends ConsumerStatefulWidget {
  const BugReportsTab({super.key});

  @override
  ConsumerState<BugReportsTab> createState() => _BugReportsTabState();
}

class _BugReportsTabState extends ConsumerState<BugReportsTab> {
  String _status = 'open';

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(adminBugReportsProvider(_status));
    return ResponsiveLayout(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'open', label: Text('Abertos')),
                ButtonSegment(value: 'resolved', label: Text('Resolvidos')),
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
                title: 'Erro ao carregar relatórios',
                description: friendlyError(e),
              ),
              data: (list) => list.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.bug_report_outlined,
                      title: 'Nenhum relatório aqui',
                      description:
                          'Os bugs enviados em Perfil > Reportar um bug aparecem nesta lista.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _BugReportCard(report: list[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BugReportCard extends ConsumerWidget {
  final AdminBugReport report;
  const _BugReportCard({required this.report});

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action, [
    String? done,
  ]) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      ref.invalidate(adminBugReportsProvider);
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
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(adminRepositoryProvider);
    final meta = [
      report.platform,
      if (report.appVersion != null) 'v${report.appVersion}',
      if (report.createdAt != null)
        DateFormatter.relativeTime(report.createdAt!),
    ].join(' · ');
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(report.description),
          const SizedBox(height: 8),
          Text(
            'Por ${report.userName ?? 'usuário removido'} · $meta',
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
              if (report.screenshotPath != null)
                TextButton.icon(
                  icon: const Icon(Icons.image_outlined, size: 16),
                  label: const Text('Ver captura'),
                  onPressed: () => _act(context, ref, () async {
                    final url = await repo.bugScreenshotUrl(
                      report.screenshotPath!,
                    );
                    await launchUrl(
                      Uri.parse(url),
                      mode: LaunchMode.externalApplication,
                    );
                  }),
                ),
              report.isOpen
                  ? FilledButton.tonal(
                      onPressed: () => _act(
                        context,
                        ref,
                        () => repo.setBugReportResolved(
                          report.id,
                          resolved: true,
                        ),
                        'Relatório marcado como resolvido.',
                      ),
                      child: const Text('Marcar resolvido'),
                    )
                  : TextButton(
                      onPressed: () => _act(
                        context,
                        ref,
                        () => repo.setBugReportResolved(
                          report.id,
                          resolved: false,
                        ),
                        'Relatório reaberto.',
                      ),
                      child: const Text('Reabrir'),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
