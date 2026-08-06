import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../providers/profile_provider.dart';

class AddPortfolioModal extends ConsumerStatefulWidget {
  const AddPortfolioModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AddPortfolioModal(),
    );
  }

  @override
  ConsumerState<AddPortfolioModal> createState() => _AddPortfolioModalState();
}

class _AddPortfolioModalState extends ConsumerState<AddPortfolioModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _projectUrlController = TextEditingController();
  final _tagsController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _imageUrlController.dispose();
    _projectUrlController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final addFn = ref.read(addPortfolioItemProvider);
      await addFn(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        imageUrl: _imageUrlController.text.trim(),
        projectUrl: _projectUrlController.text.trim().isNotEmpty
            ? _projectUrlController.text.trim()
            : null,
        tags: tags,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Projeto adicionado ao portfólio com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar projeto: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Adicionar ao Portfólio',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryDark,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _titleController,
                label: 'Título do Projeto',
                hint: 'Ex: App FreelanceFlow Mobile & Web',
                validator: (v) => v == null || v.trim().isEmpty ? 'Informe o título do projeto' : null,
              ),
              const SizedBox(height: 14),

              CustomTextField(
                controller: _descController,
                label: 'Descrição',
                hint: 'Descreva os desafios, arquitetura e resultados alcançados...',
                maxLines: 3,
                validator: (v) => v == null || v.trim().isEmpty ? 'Informe uma descrição' : null,
              ),
              const SizedBox(height: 14),

              CustomTextField(
                controller: _imageUrlController,
                label: 'URL da Imagem / Screenshot',
                hint: 'https://exemplo.com/imagem.png',
                validator: (v) => v == null || v.trim().isEmpty ? 'Informe a URL da imagem' : null,
              ),
              const SizedBox(height: 14),

              CustomTextField(
                controller: _projectUrlController,
                label: 'Link do Projeto (Opcional)',
                hint: 'https://github.com/... ou https://meuapp.com',
              ),
              const SizedBox(height: 14),

              CustomTextField(
                controller: _tagsController,
                label: 'Tecnologias / Tags (separadas por vírgula)',
                hint: 'Flutter, Supabase, Riverpod, Clean Arch',
              ),
              const SizedBox(height: 24),

              CustomButton(
                text: 'Salvar Projeto',
                isLoading: _isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
