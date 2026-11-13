import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/work_categories.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/attachment_picker_section.dart';
import '../../../../core/widgets/category_search_sheet.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../domain/entities/job.dart';
import '../providers/job_submission.dart';
import '../providers/jobs_provider.dart';
import '../widgets/job_form/job_cover_picker.dart';
import '../widgets/job_form/job_form_cards.dart';

/// Publica uma vaga ou edita [jobToEdit], inclusive capa e anexos salvos.
class CreateJobScreen extends ConsumerStatefulWidget {
  final Job? jobToEdit;

  const CreateJobScreen({super.key, this.jobToEdit});

  @override
  ConsumerState<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends ConsumerState<CreateJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _budgetMinController = TextEditingController();
  final _budgetMaxController = TextEditingController();
  final _daysController = TextEditingController();
  CategoryChoice? _category;
  List<String> _skills = [];
  bool _isUrgent = false;
  bool _isLoading = false;
  List<AppAttachment> _savedFiles = [], _keptFiles = [];
  List<PickedFileData> _newFiles = [];
  PickedFileData? _newCover;
  String? _keptCoverUrl;

  Job? get _editing => widget.jobToEdit;

  @override
  void initState() {
    super.initState();
    final job = _editing;
    if (job == null) return;
    _titleController.text = job.title;
    _descController.text = job.description;
    _budgetMinController.text = CurrencyFormatter.toInput(job.budgetMin);
    _budgetMaxController.text = CurrencyFormatter.toInput(job.budgetMax);
    _daysController.text = job.deadlineDays.toString();
    // Vaga anterior ao catálogo: converte a categoria antiga.
    _category = WorkCategories.area(job.category) == null
        ? WorkCategories.fromLegacy(job.category)
        : (area: job.category, subcategory: job.subcategory);
    _skills = List.of(job.skillsRequired);
    _isUrgent = job.isUrgent;
    _savedFiles = job.attachments.map(AppAttachment.fromJson).toList();
    _keptFiles = List.of(_savedFiles);
    _keptCoverUrl = job.imageUrl;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _budgetMinController.dispose();
    _budgetMaxController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  void _showMessage(String text, {Color? color}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }

  Future<void> _pickCover() async {
    try {
      final file = await ref.read(storageServiceProvider).pickImage();
      if (file != null) setState(() => _newCover = file);
    } catch (e) {
      if (mounted) _showMessage(friendlyError(e), color: AppColors.error);
    }
  }

  Job _job(List<Map<String, dynamic>> attachments, String? imageUrl) {
    final user = ref.read(authProvider).value!;
    final base = _editing;
    return Job(
      id: base?.id ?? '',
      clientId: base?.clientId ?? user.id,
      clientName: base?.clientName ?? (user.companyName ?? user.fullName),
      clientRating: base?.clientRating ?? user.rating,
      title: _titleController.text.trim(),
      category: _category!.area,
      subcategory: _category!.subcategory,
      description: _descController.text.trim(),
      budgetMin: CurrencyFormatter.parse(_budgetMinController.text)!,
      budgetMax: CurrencyFormatter.parse(_budgetMaxController.text)!,
      deadlineDays: int.parse(_daysController.text.trim()),
      skillsRequired: _skills,
      isUrgent: _isUrgent,
      attachments: attachments,
      imageUrl: imageUrl,
      createdAt: base?.createdAt ?? DateTime.now(),
      status: base?.status ?? JobStatus.open,
    );
  }

  JobFiles get _files => JobFiles(
    kept: _keptFiles,
    removed: _savedFiles.where((f) => !_keptFiles.contains(f)).toList(),
    added: _newFiles,
    newCover: _newCover,
    keptCoverUrl: _keptCoverUrl,
    savedCoverUrl: _editing?.imageUrl,
  );

  Future<void> _submit() async {
    // Tira o foco antes de validar: o texto digitado em Habilidades entra.
    FocusScope.of(context).unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!mounted || !(_formKey.currentState?.validate() ?? false)) return;
    if (ref.read(authProvider).value == null) {
      return _showMessage('Entre na sua conta para publicar uma vaga.');
    }
    setState(() => _isLoading = true);
    final repo = ref.read(jobRepositoryProvider);
    try {
      await saveJobWithFiles(
        store: ref.read(storageServiceProvider),
        files: _files,
        save: (attachments, cover) {
          final job = _job(attachments, cover);
          return _editing == null ? repo.createJob(job) : repo.updateJob(job);
        },
      );
      ref.invalidate(jobsListProvider);
      ref.invalidate(myOpenJobsProvider);
      ref.invalidate(clientStatsProvider);
      if (_editing case final job?) ref.invalidate(jobDetailProvider(job.id));
      if (!mounted) return;
      _showMessage(
        _editing == null ? 'Vaga publicada!' : 'Alterações salvas.',
        color: AppColors.success,
      );
      context.canPop() ? context.pop() : context.go('/jobs');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(friendlyError(e), color: AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _editing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar vaga' : 'Publicar vaga'),
        leading: AppBackButton(
          fallbackRoute: isEditing ? '/jobs/${_editing!.id}' : '/jobs',
        ),
      ),
      body: SafeArea(
        child: ResponsiveLayout(
          maxWidth: 720,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(key: _formKey, child: _form(isEditing)),
          ),
        ),
      ),
    );
  }

  Widget _form(bool isEditing) {
    const gap = SizedBox(height: 16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JobCoverPicker(
          newCover: _newCover,
          savedUrl: _keptCoverUrl,
          onPick: _pickCover,
          onRemove: () => setState(() {
            _newCover = null;
            _keptCoverUrl = null;
          }),
        ),
        gap,
        JobBasicsCard(
          titleController: _titleController,
          descriptionController: _descController,
          category: _category,
          onCategoryChanged: (v) => setState(() => _category = v),
        ),
        gap,
        JobBudgetCard(
          minController: _budgetMinController,
          maxController: _budgetMaxController,
          daysController: _daysController,
        ),
        gap,
        JobSkillsCard(
          skills: _skills,
          category: _category,
          onSkillsChanged: (v) => _skills = v,
          isUrgent: _isUrgent,
          onUrgentChanged: (v) => setState(() => _isUrgent = v),
        ),
        gap,
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: AttachmentPickerSection(
            title: 'Anexos (opcional)',
            hintText:
                'Briefing, referências, planilhas ou imagens. '
                'Até 5 arquivos no total.',
            existing: _keptFiles,
            onExistingChanged: (v) => setState(() => _keptFiles = v),
            selectedFiles: _newFiles,
            onChanged: (v) => setState(() => _newFiles = v),
          ),
        ),
        const SizedBox(height: 24),
        CustomButton(
          key: const Key('job-submit'),
          text: isEditing ? 'Salvar Alterações' : 'Publicar vaga',
          icon: isEditing ? Icons.save_rounded : Icons.rocket_launch_rounded,
          isLoading: _isLoading,
          width: double.infinity,
          onPressed: _submit,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
