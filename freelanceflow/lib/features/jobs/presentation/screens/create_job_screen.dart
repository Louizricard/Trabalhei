import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/attachment_widgets.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../domain/entities/job.dart';
import '../providers/jobs_provider.dart';

class CreateJobScreen extends ConsumerStatefulWidget {
  const CreateJobScreen({super.key});

  @override
  ConsumerState<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends ConsumerState<CreateJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _budgetMinController = TextEditingController(text: '3000');
  final _budgetMaxController = TextEditingController(text: '6000');
  final _skillsController = TextEditingController(
    text: 'Flutter, Riverpod, Supabase',
  );
  final _daysController = TextEditingController(text: '20');

  String _category = 'Mobile';
  bool _isUrgent = false;
  bool _isLoading = false;
  List<PickedFileData> _selectedFiles = [];

  final _categories = [
    'Mobile',
    'Design',
    'Fullstack',
    'Frontend',
    'Backend',
    'DevOps',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _budgetMinController.dispose();
    _budgetMaxController.dispose();
    _skillsController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _submitJob() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = ref.read(authProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Você precisa estar autenticado para publicar uma vaga.',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final storage = ref.read(storageServiceProvider);
      final uploadedAttachments = <Map<String, dynamic>>[];

      for (final file in _selectedFiles) {
        final result = await storage.uploadFile(
          bucket: 'job_attachments',
          folder: user.id,
          file: file,
        );
        if (result != null) {
          uploadedAttachments.add(result.toJson());
        }
      }

      final skills = _skillsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final job = Job(
        id: '',
        clientId: user.id,
        clientName: user.companyName ?? user.fullName,
        clientRating: user.rating,
        title: _titleController.text.trim(),
        category: _category,
        description: _descController.text.trim(),
        budgetMin: double.tryParse(_budgetMinController.text) ?? 1000,
        budgetMax: double.tryParse(_budgetMaxController.text) ?? 5000,
        deadlineDays: int.tryParse(_daysController.text) ?? 15,
        skillsRequired: skills,
        isUrgent: _isUrgent,
        attachments: uploadedAttachments,
        createdAt: DateTime.now(),
      );

      await ref.read(jobRepositoryProvider).createJob(job);
      ref.invalidate(jobsListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vaga publicada com sucesso no Trabalhei!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Falha ao publicar vaga: ${e.toString().replaceAll("Exception: ", "")}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Publicar Nova Vaga'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ResponsiveLayout(
        maxWidth: 720,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informações Básicas',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _titleController,
                        label: 'Título do Projeto',
                        hint:
                            'Ex: Desenvolvimento de App em Flutter com Chat Realtime',
                        validator: (v) => v != null && v.length >= 10
                            ? null
                            : 'Mínimo de 10 caracteres',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Categoria',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        items: _categories
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _category = val ?? 'Mobile'),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _descController,
                        label: 'Descrição Detalhada dos Requisitos',
                        hint:
                            'Explique os objetivos, entregáveis esperados, integrações e escopo do projeto...',
                        maxLines: 5,
                        validator: (v) => v != null && v.length >= 30
                            ? null
                            : 'Mínimo de 30 caracteres',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Orçamento e Prazos',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _budgetMinController,
                              label: 'Orçamento Mínimo (R\$)',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomTextField(
                              controller: _budgetMaxController,
                              label: 'Orçamento Máximo (R\$)',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _daysController,
                        label: 'Prazo Previsto de Execução (Dias)',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _skillsController,
                        label: 'Habilidades Desejadas (separadas por vírgula)',
                        hint: 'Flutter, Riverpod, GoRouter, Supabase',
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Destacar como Urgente 🔥',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: const Text(
                          'Aparece em destaque no topo do mural para freelancers',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMutedDark,
                          ),
                        ),
                        value: _isUrgent,
                        onChanged: (val) => setState(() => _isUrgent = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: AttachmentPickerSection(
                    selectedFiles: _selectedFiles,
                    onChanged: (files) =>
                        setState(() => _selectedFiles = files),
                    title: 'Anexos e Especificações da Vaga',
                    hintText:
                        'Adicione briefings, PDFs, protótipos em imagem ou documentos para orientar os freelancers.',
                  ),
                ),
                const SizedBox(height: 24),
                CustomButton(
                  text: 'Confirmar e Publicar Projeto',
                  icon: Icons.rocket_launch_rounded,
                  isLoading: _isLoading,
                  width: double.infinity,
                  onPressed: _submitJob,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
