import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../auth/presentation/guest_access.dart';
import '../../domain/entities/job.dart';
import '../../domain/entities/job_alert.dart';
import '../../domain/repositories/job_repository.dart';
import '../providers/job_alerts_provider.dart';
import '../providers/jobs_provider.dart';

/// Filtros avançados do mural, com a opção de salvar a busca como alerta.
/// [query] e [category] vêm da busca e das categorias do próprio mural.
class JobFilterSheet extends ConsumerStatefulWidget {
  final String? query;
  final String? category;

  const JobFilterSheet({super.key, this.query, this.category});

  static Future<void> show(
    BuildContext context, {
    String? query,
    String? category,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => JobFilterSheet(query: query, category: category),
  );

  @override
  ConsumerState<JobFilterSheet> createState() => _JobFilterSheetState();
}

class _JobFilterSheetState extends ConsumerState<JobFilterSheet> {
  late ExperienceLevel _exp;
  ContractType? _contract;
  int? _maxDeadline;
  double? _minRating;
  late bool _urgentOnly;
  late String _sort;
  final _minBudget = TextEditingController();
  bool _saving = false;

  static const _deadlines = [7, 15, 30, 60];
  static const _ratings = [3.0, 4.0, 4.5];

  @override
  void initState() {
    super.initState();
    final f = ref.read(jobFilterProvider);
    _exp = f.experienceLevel ?? ExperienceLevel.all;
    _contract = f.contractType;
    _maxDeadline = f.maxDeadlineDays;
    _minRating = f.minClientRating;
    _urgentOnly = f.urgentOnly;
    _sort = f.sortBy;
    if (f.minBudget != null) _minBudget.text = f.minBudget!.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _minBudget.dispose();
    super.dispose();
  }

  JobFilter get _filter => JobFilter(
    searchQuery: ref.read(jobFilterProvider).searchQuery,
    category: ref.read(jobFilterProvider).category,
    experienceLevel: _exp,
    contractType: _contract,
    minBudget: double.tryParse(_minBudget.text.trim()),
    maxDeadlineDays: _maxDeadline,
    minClientRating: _minRating,
    urgentOnly: _urgentOnly,
    sortBy: _sort,
  );

  void _apply() {
    ref.read(jobFilterProvider.notifier).state = _filter;
    Navigator.of(context).pop();
  }

  void _reset() {
    ref.read(jobFilterProvider.notifier).state = const JobFilter();
    Navigator.of(context).pop();
  }

  Future<void> _saveAlert() async {
    if (!await requireAccount(
      context,
      ref,
      action: 'salvar alertas de vagas',
    )) {
      return;
    }
    if (!mounted) return;
    final suggestion = [
      if (widget.query?.trim().isNotEmpty == true) widget.query!.trim(),
      ?widget.category,
    ].join(' · ');
    final name = await _askName(
      suggestion.isEmpty ? 'Vagas novas' : suggestion,
    );
    if (name == null || !mounted) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref
          .read(jobAlertRepositoryProvider)
          .create(
            JobAlert.insertJson(
              name: name,
              filter: _filter,
              query: widget.query,
              category: widget.category,
            ),
          );
      ref.invalidate(jobAlertsProvider);
      ref.read(jobFilterProvider.notifier).state = _filter;
      if (mounted) Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Alerta salvo. Avisamos quando sair uma vaga compatível.',
          ),
          backgroundColor: AppColors.success,
          action: SnackBarAction(
            label: 'Ver alertas',
            textColor: AppColors.onPrimary,
            onPressed: () => router.push('/alerts'),
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(friendlyError(e)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<String?> _askName(String suggestion) {
    final controller = TextEditingController(text: suggestion);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nome do alerta'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(hintText: 'Ex.: Apps Flutter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.of(ctx).pop(name);
            },
            child: const Text('Salvar alerta'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        maxWidth: 640,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filtros de vagas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  TextButton(onPressed: _reset, child: const Text('Limpar')),
                ],
              ),
              _section('Nível de experiência'),
              _chips<ExperienceLevel>(
                {
                  ExperienceLevel.all: 'Todos',
                  ExperienceLevel.junior: 'Júnior',
                  ExperienceLevel.pleno: 'Pleno',
                  ExperienceLevel.senior: 'Sênior',
                },
                _exp,
                (v) => setState(() => _exp = v ?? ExperienceLevel.all),
              ),
              _section('Tipo de contrato'),
              _chips<ContractType?>(
                {
                  null: 'Qualquer',
                  ContractType.fixed: 'Preço fixo',
                  ContractType.hourly: 'Por hora',
                },
                _contract,
                (v) => setState(() => _contract = v),
              ),
              _section('Orçamento'),
              TextField(
                controller: _minBudget,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(7),
                ],
                decoration: const InputDecoration(
                  labelText: 'Pagando a partir de (R\$)',
                  hintText: 'Ex.: 1000',
                ),
              ),
              _section('Prazo de entrega'),
              _chips<int?>(
                {
                  null: 'Qualquer',
                  for (final d in _deadlines) d: 'Até $d dias',
                },
                _maxDeadline,
                (v) => setState(() => _maxDeadline = v),
              ),
              _section('Nota do cliente'),
              _chips<double?>(
                {
                  null: 'Qualquer',
                  for (final r in _ratings)
                    r: '${r.toString().replaceAll('.', ',')}+ estrelas',
                },
                _minRating,
                (v) => setState(() => _minRating = v),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Só vagas urgentes'),
                value: _urgentOnly,
                onChanged: (v) => setState(() => _urgentOnly = v),
              ),
              _section('Ordenar por'),
              _chips<String>(
                {
                  'recent': 'Mais recentes',
                  'budget_desc': 'Maior orçamento',
                  'proposals_asc': 'Menos propostas',
                },
                _sort,
                (v) => setState(() => _sort = v ?? 'recent'),
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Aplicar filtros',
                onPressed: _apply,
                width: double.infinity,
              ),
              const SizedBox(height: 12),
              CustomButton(
                text: 'Salvar como alerta',
                icon: Icons.notifications_active_outlined,
                variant: ButtonVariant.outline,
                isLoading: _saving,
                onPressed: _saveAlert,
                width: double.infinity,
              ),
              const SizedBox(height: 8),
              const Text(
                'O alerta usa a busca, a categoria e os filtros acima, e avisa por notificação, e-mail e push quando sair uma vaga compatível.',
                style: TextStyle(fontSize: 12, color: AppColors.textMutedDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondaryDark,
      ),
    ),
  );

  Widget _chips<T>(
    Map<T, String> options,
    T selected,
    ValueChanged<T?> onSelect,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in options.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: entry.key == selected,
            onSelected: (_) => onSelect(entry.key),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surfaceElevatedDark,
            labelStyle: TextStyle(
              color: entry.key == selected
                  ? AppColors.onPrimary
                  : AppColors.textSecondaryDark,
              fontWeight: entry.key == selected
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
      ],
    );
  }
}
