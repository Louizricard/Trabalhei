import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../jobs/domain/entities/job.dart';
import '../../../jobs/presentation/providers/jobs_provider.dart';
import '../../domain/entities/proposal.dart';
import '../../domain/entities/proposal_action.dart';
import '../providers/proposal_submission.dart';
import '../providers/proposals_provider.dart';
import '../widgets/apply/apply_job_summary.dart';
import '../widgets/apply/counter_offer_banner.dart';
import '../widgets/apply/proposal_form_cards.dart';
import '../widgets/apply/proposal_quota_banner.dart';
import 'proposal_templates_screen.dart';

class ApplyJobScreen extends ConsumerStatefulWidget {
  final String jobId;

  const ApplyJobScreen({super.key, required this.jobId});

  @override
  ConsumerState<ApplyJobScreen> createState() => _ApplyJobScreenState();
}

class _ApplyJobScreenState extends ConsumerState<ApplyJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bidController = TextEditingController();
  final _daysController = TextEditingController();
  final _coverLetterController = TextEditingController();
  bool _isLoading = false;
  Proposal? _existing;
  List<String> _links = [];
  List<AppAttachment> _savedFiles = [];
  List<AppAttachment> _keptFiles = [];
  List<PickedFileData> _newFiles = [];

  // Sem marcos informados, o servidor cria um marco único com o valor total.
  List<ProposedMilestone> _milestones = [];

  bool get _isEditing => _existing != null;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _bidController.dispose();
    _daysController.dispose();
    _coverLetterController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final user = ref.read(authProvider).value;
    if (user == null) return;
    try {
      final list = await ref
          .read(proposalRepositoryProvider)
          .getFreelancerProposals(user.id);
      final prop = list.where((p) => p.jobId == widget.jobId).firstOrNull;
      if (prop == null || !mounted) return;
      final files = prop.attachments.map(AppAttachment.fromJson).toList();
      setState(() {
        _existing = prop;
        _bidController.text = CurrencyFormatter.toInput(prop.bidAmount);
        _daysController.text = prop.estimatedDays.toString();
        _coverLetterController.text = prop.coverLetter;
        _milestones = List.of(prop.proposedMilestones);
        _links = List.of(prop.portfolioLinks);
        _savedFiles = files;
        _keptFiles = List.of(files);
      });
    } catch (_) {
      // Sem a proposta anterior, segue com o formulário em branco.
    }
  }

  void _showMessage(String text, {Color? color, SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color, action: action),
    );
  }

  Future<void> _applyTemplate() async {
    final template = await pickProposalTemplate(
      context,
      ref,
      currentText: _coverLetterController.text,
      currentDays: int.tryParse(_daysController.text),
    );
    if (template == null || !mounted) return;
    setState(() {
      _coverLetterController.text = template.coverLetter;
      if (template.estimatedDays != null) {
        _daysController.text = '${template.estimatedDays}';
      }
    });
  }

  Proposal _proposal() {
    final user = ref.read(authProvider).value!;
    return Proposal(
      id: _existing?.id ?? '',
      jobId: widget.jobId,
      freelancerId: user.id,
      freelancerName: user.fullName,
      freelancerRating: user.rating,
      bidAmount: CurrencyFormatter.parse(_bidController.text) ?? 0,
      estimatedDays: int.parse(_daysController.text),
      coverLetter: _coverLetterController.text.trim(),
      proposedMilestones: _milestones,
      portfolioLinks: _links,
      createdAt: DateTime.now(),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (ref.read(authProvider).value == null) {
      return _showMessage('Entre na sua conta para enviar propostas.');
    }
    setState(() => _isLoading = true);
    try {
      await submitProposalWithFiles(
        ref,
        proposal: _proposal(),
        kept: _keptFiles,
        removed: _savedFiles.where((f) => !_keptFiles.contains(f)).toList(),
        newFiles: _newFiles,
      );
      if (!mounted) return;
      _showMessage(
        _isEditing
            ? 'Proposta atualizada.'
            : 'Proposta enviada! O cliente foi notificado.',
        color: AppColors.success,
      );
      context.canPop() ? context.pop() : context.go('/jobs/${widget.jobId}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final quota =
          e.toString().contains('PROPOSAL_QUOTA_EXCEEDED') &&
          !(ref.read(authProvider).valueOrNull?.isPro ?? false);
      _showMessage(
        friendlyError(e),
        color: AppColors.error,
        action: quota
            ? SnackBarAction(
                label: 'Ver planos',
                textColor: AppColors.pureWhite,
                onPressed: () => context.push('/plans'),
              )
            : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(jobDetailProvider(widget.jobId)).value;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar proposta' : 'Enviar proposta'),
        leading: AppBackButton(fallbackRoute: '/jobs/${widget.jobId}'),
      ),
      body: ResponsiveLayout(
        maxWidth: 700,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(key: _formKey, child: _form(job)),
        ),
      ),
    );
  }

  Widget _form(Job? job) {
    // Mínimo definido no servidor (platform_settings), contra envio em massa.
    final minCoverLetter =
        ref.watch(proposalQuotaProvider).valueOrNull?.minCoverLetterChars ?? 50;
    final blockedReason = ProposalAction.of(
      job?.status ?? JobStatus.open,
      _existing,
    ).blockedReason;
    const gap = SizedBox(height: 20);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._notices(blockedReason),
        ProposalQuotaBanner(isEditing: _isEditing),
        if (job != null) ...[ApplyJobSummary(job: job), gap],
        ProposalTermsCard(
          bidController: _bidController,
          daysController: _daysController,
        ),
        gap,
        CoverLetterCard(
          controller: _coverLetterController,
          minChars: minCoverLetter,
          onUseTemplate: _applyTemplate,
        ),
        gap,
        ProposalPortfolioCard(
          links: _links,
          onLinksChanged: (v) => setState(() => _links = v),
          existingFiles: _keptFiles,
          onExistingFilesChanged: (v) => setState(() => _keptFiles = v),
          newFiles: _newFiles,
          onNewFilesChanged: (v) => setState(() => _newFiles = v),
        ),
        const SizedBox(height: 24),
        ProposalSubmitArea(
          blockedReason: blockedReason,
          isEditing: _isEditing,
          isLoading: _isLoading,
          onSubmit: _submit,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  List<Widget> _notices(String? blockedReason) {
    if (_existing case final p? when p.hasActiveCounterOffer) {
      return [
        CounterOfferBanner(
          proposal: p,
          onRejected: (updated) => setState(() => _existing = updated),
        ),
        const SizedBox(height: 16),
      ];
    }
    return [
      if (_isEditing && blockedReason == null) const EditingProposalNotice(),
    ];
  }
}
