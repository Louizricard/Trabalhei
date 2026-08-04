import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../providers/profile_provider.dart';

class EditProfileModal extends ConsumerStatefulWidget {
  final UserProfile user;

  const EditProfileModal({super.key, required this.user});

  @override
  ConsumerState<EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends ConsumerState<EditProfileModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _hourlyRateController;
  late final TextEditingController _skillsController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName);
    _bioController = TextEditingController(text: widget.user.bio ?? '');
    _hourlyRateController = TextEditingController(
      text: widget.user.hourlyRate > 0 ? widget.user.hourlyRate.toStringAsFixed(0) : '',
    );
    _skillsController = TextEditingController(text: widget.user.skills.join(', '));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _hourlyRateController.dispose();
    _skillsController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final skillsList = _skillsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final hourlyRate = double.tryParse(_hourlyRateController.text.trim());

      final updateFn = ref.read(updateProfileProvider);
      await updateFn(
        fullName: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        hourlyRate: hourlyRate,
        skills: skillsList,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil atualizado com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao atualizar perfil: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFreelancer = widget.user.role == UserRole.freelancer;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Editar Perfil',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _nameController,
                label: 'Nome Completo',
                hint: 'Seu nome',
                prefixIcon: Icons.person_outline_rounded,
                validator: (v) => v == null || v.trim().isEmpty ? 'Nome é obrigatório' : null,
              ),
              const SizedBox(height: 14),
              CustomTextField(
                controller: _bioController,
                label: 'Sobre Você (Bio)',
                hint: 'Conte sobre sua experiência, histórico e especialidades...',
                prefixIcon: Icons.description_outlined,
                maxLines: 3,
              ),
              if (isFreelancer) ...[
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _hourlyRateController,
                  label: 'Valor/Hora (R\$)',
                  hint: 'Ex: 120',
                  prefixIcon: Icons.payments_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _skillsController,
                  label: 'Habilidades & Tecnologias',
                  hint: 'Ex: Flutter, Dart, Riverpod, Supabase (separadas por vírgula)',
                  prefixIcon: Icons.code_rounded,
                ),
              ],
              const SizedBox(height: 24),
              CustomButton(
                text: 'Salvar Alterações',
                icon: Icons.check_rounded,
                isLoading: _isLoading,
                onPressed: _handleSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
