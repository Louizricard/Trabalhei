import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/supabase_client.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../billing/presentation/widgets/pro_upsell.dart';
import '../../data/pro_insights_repository.dart';
import '../../domain/entities/pro_insights.dart';

final proInsightsRepositoryProvider = Provider<ProInsightsRepository>(
  (ref) => ProInsightsRepository(ref.watch(supabaseClientProvider)),
);

final proposalStatsProvider = FutureProvider.autoDispose
    .family<ProposalStats, int>(
      (ref, days) =>
          ref.watch(proInsightsRepositoryProvider).proposalStats(days),
    );

final freelancerClientsProvider =
    FutureProvider.autoDispose<List<ClientSummary>>(
      (ref) => ref.watch(proInsightsRepositoryProvider).clients(),
    );

const statsUpsell =
    'Veja quantas propostas foram aceitas, quanto tempo os clientes levam para '
    'responder, como seus valores se comparam aos orçamentos e em quais '
    'categorias você vai melhor.';
const clientsUpsell =
    'Todos os clientes com quem você negociou, com projetos, valores e '
    'anotações privadas, em um só lugar.';

String _pct(double v) => '${(v * 100).round()}%';

// ---------------------------------------------------------------- Estatísticas
class ProposalStatsScreen extends ConsumerStatefulWidget {
  const ProposalStatsScreen({super.key});

  @override
  ConsumerState<ProposalStatsScreen> createState() =>
      _ProposalStatsScreenState();
}

class _ProposalStatsScreenState extends ConsumerState<ProposalStatsScreen> {
  int _days = 90;

  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(authProvider).valueOrNull?.isPro ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Estatísticas das propostas')),
      body: ResponsiveLayout(
        maxWidth: 820,
        child: !isPro
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  ProLockedCard(
                    icon: Icons.insights_rounded,
                    title: 'Estatísticas das propostas',
                    description: statsUpsell,
                  ),
                ],
              )
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(proposalStatsProvider(_days)),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 30, label: Text('30 dias')),
                        ButtonSegment(value: 90, label: Text('90 dias')),
                        ButtonSegment(value: 365, label: Text('12 meses')),
                      ],
                      selected: {_days},
                      onSelectionChanged: (s) =>
                          setState(() => _days = s.first),
                    ),
                    const SizedBox(height: 16),
                    ref
                        .watch(proposalStatsProvider(_days))
                        .when(
                          loading: () => const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (e, _) => EmptyStateWidget(
                            icon: Icons.error_outline_rounded,
                            title: 'Erro ao carregar estatísticas',
                            description: friendlyError(e),
                          ),
                          data: (s) => s.sent == 0
                              ? const EmptyStateWidget(
                                  icon: Icons.insights_rounded,
                                  title: 'Sem propostas no período',
                                  description:
                                      'Envie propostas e acompanhe aqui como elas se saem.',
                                )
                              : _StatsBody(stats: s),
                        ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  final ProposalStats stats;
  const _StatsBody({required this.stats});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final kpis = [
      ('Enviadas', '${s.sent}', '${s.pending} aguardando resposta'),
      (
        'Taxa de aceite',
        _pct(s.acceptanceRate),
        '${s.accepted} aceitas de ${s.accepted + s.rejected} decididas',
      ),
      (
        'Com resposta',
        _pct(s.responseRate),
        'aceitas, recusadas ou negociadas',
      ),
      (
        'Tempo até a decisão',
        s.avgDecisionHours == null
            ? '—'
            : s.avgDecisionHours! < 48
            ? '${s.avgDecisionHours!.round()} h'
            : '${(s.avgDecisionHours! / 24).round()} dias',
        'média até aceitar ou recusar',
      ),
      (
        'Seu valor x orçamento',
        s.avgBidVsBudget == null ? '—' : _pct(s.avgBidVsBudget!),
        'do teto do orçamento do cliente',
      ),
      (
        'Valor médio',
        s.avgBid == null ? '—' : CurrencyFormatter.format(s.avgBid!),
        'por proposta',
      ),
    ];
    final maxSent = s.byMonth.fold<int>(1, (m, e) => e.sent > m ? e.sent : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth > 600 ? 3 : 2;
            final w = (c.maxWidth - (cols - 1) * 12) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final k in kpis)
                  SizedBox(
                    width: w,
                    child: GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            k.$1,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMutedDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            k.$2,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            k.$3,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        if (s.byMonth.length > 1) ...[
          const _Title('Por mês'),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final m in s.byMonth)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${m.sent}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 90 * m.sent / maxSent,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(90),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: m.sent == 0
                                    ? 0
                                    : m.accepted / m.sent,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              m.month.length >= 7
                                  ? '${m.month.substring(5, 7)}/${m.month.substring(2, 4)}'
                                  : m.month,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMutedDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Barra clara: enviadas · barra cheia: aceitas',
              style: TextStyle(fontSize: 11, color: AppColors.textMutedDark),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (s.byCategory.isNotEmpty) ...[
          const _Title('Por categoria'),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (final c in s.byCategory)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(
                            c.category,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: c.acceptanceRate,
                              minHeight: 8,
                              backgroundColor: AppColors.borderDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 92,
                          child: Text(
                            '${c.accepted}/${c.sent} aceitas',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);

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

// ---------------------------------------------------------------- Clientes
class ClientsScreen extends ConsumerWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(authProvider).valueOrNull?.isPro ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes e projetos')),
      body: ResponsiveLayout(
        maxWidth: 820,
        child: !isPro
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  ProLockedCard(
                    icon: Icons.groups_2_outlined,
                    title: 'Clientes e projetos',
                    description: clientsUpsell,
                  ),
                ],
              )
            : ref
                  .watch(freelancerClientsProvider)
                  .when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => EmptyStateWidget(
                      icon: Icons.error_outline_rounded,
                      title: 'Erro ao carregar clientes',
                      description: friendlyError(e),
                    ),
                    data: (list) => list.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.groups_2_outlined,
                            title: 'Nenhum cliente ainda',
                            description:
                                'Os clientes aparecem aqui assim que você envia a primeira proposta para eles.',
                          )
                        : RefreshIndicator(
                            onRefresh: () async =>
                                ref.invalidate(freelancerClientsProvider),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: list.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, i) =>
                                  _ClientCard(client: list[i]),
                            ),
                          ),
                  ),
      ),
    );
  }
}

class _ClientCard extends ConsumerWidget {
  final ClientSummary client;
  const _ClientCard({required this.client});

  Future<void> _editNote(BuildContext context, WidgetRef ref) async {
    final note = TextEditingController(text: client.note);
    final tags = TextEditingController(text: client.tags.join(', '));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Anotações sobre ${client.name}'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: note,
                maxLines: 5,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Anotação (só você vê)',
                  hintText: 'Ex.: prefere falar por mensagem pela manhã',
                  alignLabelWithHint: true,
                ),
              ),
              TextField(
                controller: tags,
                decoration: const InputDecoration(
                  labelText: 'Etiquetas, separadas por vírgula',
                  hintText: 'Ex.: recorrente, paga em dia',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final parsed = tags.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .take(10)
          .toList();
      try {
        await ref
            .read(proInsightsRepositoryProvider)
            .saveNote(client.clientId, note.text, parsed);
        ref.invalidate(freelancerClientsProvider);
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
    }
    note.dispose();
    tags.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = client;
    final summary = [
      '${c.proposals} proposta${c.proposals == 1 ? '' : 's'}',
      if (c.accepted > 0) '${c.accepted} aceita${c.accepted == 1 ? '' : 's'}',
      if (c.activeContracts > 0) '${c.activeContracts} em andamento',
      if (c.completedContracts > 0) '${c.completedContracts} concluído(s)',
    ].join(' · ');
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: CircleAvatar(
            backgroundColor: AppColors.primaryContainer,
            child: Text(
              c.name.trim().isEmpty ? 'C' : c.name.trim()[0].toUpperCase(),
              style: const TextStyle(color: AppColors.primary),
            ),
          ),
          title: Text(
            c.company?.isNotEmpty == true ? '${c.name} · ${c.company}' : c.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            summary,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryDark,
            ),
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    c.totalAccepted > 0
                        ? 'Total em propostas aceitas: ${CurrencyFormatter.format(c.totalAccepted)}'
                        : 'Nenhuma proposta aceita ainda',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/profile/${c.clientId}'),
                  child: const Text('Ver perfil'),
                ),
              ],
            ),
            if (c.tags.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in c.tags)
                      Chip(
                        label: Text(t),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _editNote(context, ref),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.sticky_note_2_outlined,
                      size: 18,
                      color: AppColors.textMutedDark,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c.note.isEmpty
                            ? 'Adicionar anotação e etiquetas (só você vê)'
                            : c.note,
                        style: TextStyle(
                          fontSize: 13,
                          color: c.note.isEmpty
                              ? AppColors.textMutedDark
                              : AppColors.textPrimaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final p in c.projects)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(p.title),
                subtitle: Text(
                  '${p.label} · ${CurrencyFormatter.format(p.bid)} · ${DateFormatter.simpleDate(p.createdAt)}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/jobs/${p.jobId}'),
              ),
          ],
        ),
      ),
    );
  }
}
