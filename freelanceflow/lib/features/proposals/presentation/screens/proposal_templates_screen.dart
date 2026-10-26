import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_client.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../billing/presentation/widgets/pro_upsell.dart';
import '../../data/proposal_template_repository.dart';
import '../../domain/entities/proposal_template.dart';

final proposalTemplateRepositoryProvider = Provider<ProposalTemplateRepository>(
  (ref) => ProposalTemplateRepository(ref.watch(supabaseClientProvider)),
);

final proposalTemplatesProvider =
    FutureProvider.autoDispose<List<ProposalTemplate>>(
      (ref) => ref.watch(proposalTemplateRepositoryProvider).list(),
    );

const _upsellText =
    'Salve cartas de apresentação e prazos que você usa sempre e aplique em '
    'um toque, ajustando para cada vaga.';

/// Modelos de proposta (Pro): criar, editar e apagar.
class ProposalTemplatesScreen extends ConsumerWidget {
  const ProposalTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(authProvider).valueOrNull?.isPro ?? false;
    final templates = ref.watch(proposalTemplatesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Modelos de proposta')),
      floatingActionButton: isPro
          ? FloatingActionButton.extended(
              onPressed: () => editProposalTemplate(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Novo modelo'),
            )
          : null,
      body: ResponsiveLayout(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (!isPro) ...[
              const ProLockedCard(
                icon: Icons.content_paste_rounded,
                title: 'Modelos de proposta',
                description: _upsellText,
              ),
              const SizedBox(height: 16),
            ],
            templates.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => EmptyStateWidget(
                icon: Icons.error_outline_rounded,
                title: 'Erro ao carregar modelos',
                description: friendlyError(e),
              ),
              data: (list) => list.isEmpty
                  ? (isPro
                        ? const EmptyStateWidget(
                            icon: Icons.content_paste_rounded,
                            title: 'Nenhum modelo ainda',
                            description:
                                'Crie um modelo aqui ou, ao enviar uma proposta, toque em "Modelos" > "Salvar como modelo".',
                          )
                        : const SizedBox.shrink())
                  : Column(
                      children: [
                        for (final t in list) ...[
                          _TemplateTile(template: t, canEdit: isPro),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateTile extends ConsumerWidget {
  final ProposalTemplate template;
  final bool canEdit;

  const _TemplateTile({required this.template, required this.canEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  template.coverLetter,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (template.estimatedDays != null)
                      'Prazo: ${template.estimatedDays} dias',
                    'Atualizado ${DateFormatter.relativeTime(template.updatedAt)}',
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMutedDark,
                  ),
                ),
              ],
            ),
          ),
          if (canEdit)
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  editProposalTemplate(context, ref, template: template),
            ),
          IconButton(
            tooltip: 'Apagar',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              try {
                await ref
                    .read(proposalTemplateRepositoryProvider)
                    .delete(template.id);
              } catch (e) {
                if (context.mounted) _snack(context, friendlyError(e), true);
              }
              ref.invalidate(proposalTemplatesProvider);
            },
          ),
        ],
      ),
    );
  }
}

void _snack(BuildContext context, String text, [bool error = false]) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text),
      backgroundColor: error ? AppColors.error : AppColors.success,
    ),
  );
}

/// Cria (ou edita) um modelo. [initialText] e [initialDays] pré-preenchem um
/// modelo novo, ex.: a carta que a pessoa está escrevendo.
Future<void> editProposalTemplate(
  BuildContext context,
  WidgetRef ref, {
  ProposalTemplate? template,
  String? initialText,
  int? initialDays,
}) async {
  final isPro = ref.read(authProvider).valueOrNull?.isPro ?? false;
  if (!isPro) {
    return showProUpsell(
      context,
      feature: 'Modelos de proposta',
      description: _upsellText,
    );
  }
  final title = TextEditingController(text: template?.title ?? '');
  final text = TextEditingController(
    text: template?.coverLetter ?? initialText ?? '',
  );
  final days = TextEditingController(
    text: '${template?.estimatedDays ?? initialDays ?? ''}',
  );
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(template == null ? 'Novo modelo' : 'Editar modelo'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Nome do modelo',
                  hintText: 'Ex.: App Flutter completo',
                ),
              ),
              TextField(
                controller: text,
                maxLines: 8,
                maxLength: 3000,
                decoration: const InputDecoration(
                  labelText: 'Carta de apresentação',
                  alignLabelWithHint: true,
                ),
              ),
              TextField(
                controller: days,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                decoration: const InputDecoration(
                  labelText: 'Prazo habitual em dias (opcional)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (title.text.trim().isEmpty || text.text.trim().isEmpty) return;
            Navigator.of(ctx).pop(true);
          },
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
  if (saved == true && context.mounted) {
    final repo = ref.read(proposalTemplateRepositoryProvider);
    final parsedDays = int.tryParse(days.text);
    try {
      if (template == null) {
        await repo.create(
          title: title.text,
          coverLetter: text.text,
          estimatedDays: parsedDays,
        );
      } else {
        await repo.update(
          template.id,
          title: title.text,
          coverLetter: text.text,
          estimatedDays: parsedDays,
        );
      }
      if (context.mounted) _snack(context, 'Modelo salvo.');
    } catch (e) {
      if (context.mounted) _snack(context, friendlyError(e), true);
    }
    ref.invalidate(proposalTemplatesProvider);
  }
  title.dispose();
  text.dispose();
  days.dispose();
}

/// Escolhe um modelo para aplicar na proposta. Retorna `null` se cancelar.
Future<ProposalTemplate?> pickProposalTemplate(
  BuildContext context,
  WidgetRef ref, {
  required String currentText,
  int? currentDays,
}) async {
  final isPro = ref.read(authProvider).valueOrNull?.isPro ?? false;
  if (!isPro) {
    await showProUpsell(
      context,
      feature: 'Modelos de proposta',
      description: _upsellText,
    );
    return null;
  }
  return showModalBottomSheet<ProposalTemplate>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceDark,
    builder: (sheetContext) => Consumer(
      builder: (sheetContext, sheetRef, _) {
        final templates = sheetRef.watch(proposalTemplatesProvider);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                const Text(
                  'Modelos de proposta',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'O texto entra na carta e você ajusta para esta vaga.',
                  style: TextStyle(color: AppColors.textSecondaryDark),
                ),
                const SizedBox(height: 12),
                ...templates.when(
                  loading: () => [
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                  error: (e, _) => [Text(friendlyError(e))],
                  data: (list) => [
                    if (list.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Você ainda não tem modelos.',
                          style: TextStyle(color: AppColors.textMutedDark),
                        ),
                      ),
                    for (final t in list)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.content_paste_rounded),
                        title: Text(t.title),
                        subtitle: Text(
                          t.coverLetter,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.of(sheetContext).pop(t),
                      ),
                  ],
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.save_outlined),
                  title: const Text('Salvar a carta atual como modelo'),
                  enabled: currentText.trim().isNotEmpty,
                  onTap: () {
                    // Usa o contexto da tela (a folha some ao fechar).
                    Navigator.of(sheetContext).pop();
                    editProposalTemplate(
                      context,
                      ref,
                      initialText: currentText,
                      initialDays: currentDays,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
