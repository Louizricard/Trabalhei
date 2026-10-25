import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../domain/entities/profile_update.dart';
import '../providers/profile_provider.dart';
import 'resume_field.dart';

/// Edição do próprio perfil. Os limites de tamanho são os mesmos do banco.
class EditProfileModal extends ConsumerStatefulWidget {
  final UserProfile user;

  const EditProfileModal({super.key, required this.user});

  @override
  ConsumerState<EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends ConsumerState<EditProfileModal> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.fullName);
  late final _headline = TextEditingController(text: widget.user.headline);
  late final _company = TextEditingController(text: widget.user.companyName);
  late final _location = TextEditingController(text: widget.user.location);
  late final _bio = TextEditingController(text: widget.user.bio);
  late final _rate = TextEditingController(
    text: widget.user.hourlyRate > 0
        ? widget.user.hourlyRate.toStringAsFixed(0)
        : '',
  );
  late final _skills = TextEditingController(
    text: widget.user.skills.join(', '),
  );
  late final _website = TextEditingController(text: widget.user.websiteUrl);
  late final _linkedin = TextEditingController(text: widget.user.linkedinUrl);
  late final _github = TextEditingController(text: widget.user.githubUrl);
  bool _isLoading = false;

  bool get _isFreelancer => widget.user.role == UserRole.freelancer;

  @override
  void dispose() {
    for (final c in [
      _name,
      _headline,
      _company,
      _location,
      _bio,
      _rate,
      _skills,
      _website,
      _linkedin,
      _github,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _skillList => _skills.text
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(updateProfileProvider)(
        ProfileUpdate(
          fullName: _name.text,
          headline: _headline.text,
          location: _location.text,
          bio: _bio.text,
          websiteUrl: _website.text,
          linkedinUrl: _linkedin.text,
          githubUrl: _isFreelancer ? _github.text : '',
          skills: _isFreelancer ? _skillList : widget.user.skills,
          hourlyRate: _isFreelancer
              ? double.tryParse(_rate.text.trim()) ?? 0
              : null,
          companyName: _isFreelancer ? null : _company.text,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil atualizado!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível salvar: ${friendlyError(e)}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String? _skillsValidator(String? _) {
    final list = _skillList;
    if (list.length > 20) return 'Use no máximo 20 habilidades.';
    if (list.any((s) => s.length > 40)) {
      return 'Cada habilidade pode ter até 40 caracteres.';
    }
    return null;
  }

  Widget _gap() => const SizedBox(height: 14);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
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
                children: [
                  const Expanded(
                    child: Text(
                      'Editar perfil',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _name,
                label: 'Nome completo',
                prefixIcon: Icons.person_outline_rounded,
                maxLength: 120,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Informe seu nome' : null,
              ),
              _gap(),
              CustomTextField(
                controller: _headline,
                label: _isFreelancer ? 'Título profissional' : 'Cargo ou área',
                hint: _isFreelancer
                    ? 'Ex.: Desenvolvedor Flutter'
                    : 'Ex.: Gerente de produto',
                prefixIcon: Icons.badge_outlined,
                maxLength: 80,
              ),
              if (!_isFreelancer) ...[
                _gap(),
                CustomTextField(
                  controller: _company,
                  label: 'Empresa',
                  prefixIcon: Icons.business_outlined,
                  maxLength: 120,
                ),
              ],
              _gap(),
              CustomTextField(
                controller: _location,
                label: 'Cidade',
                hint: 'Ex.: Goiânia, GO',
                prefixIcon: Icons.place_outlined,
                maxLength: 80,
              ),
              _gap(),
              CustomTextField(
                controller: _bio,
                label: 'Sobre você',
                hint: 'Experiência, especialidades e como você trabalha',
                prefixIcon: Icons.description_outlined,
                maxLines: 5,
                maxLength: 2000,
              ),
              if (_isFreelancer) ...[
                _gap(),
                CustomTextField(
                  controller: _rate,
                  label: 'Valor por hora (R\$)',
                  hint: 'Ex.: 120',
                  prefixIcon: Icons.payments_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                ),
                _gap(),
                CustomTextField(
                  controller: _skills,
                  label: 'Habilidades',
                  hint: 'Separadas por vírgula. Ex.: Flutter, Figma, SQL',
                  prefixIcon: Icons.code_rounded,
                  validator: _skillsValidator,
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'Links',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryDark,
                ),
              ),
              const SizedBox(height: 10),
              CustomTextField(
                controller: _website,
                label: _isFreelancer ? 'Site ou portfólio' : 'Site da empresa',
                hint: 'https://',
                prefixIcon: Icons.language_rounded,
                keyboardType: TextInputType.url,
                validator: Validators.optionalUrl,
              ),
              _gap(),
              CustomTextField(
                controller: _linkedin,
                label: 'LinkedIn',
                hint: 'https://www.linkedin.com/in/...',
                prefixIcon: Icons.work_outline_rounded,
                keyboardType: TextInputType.url,
                validator: Validators.optionalUrl,
              ),
              if (_isFreelancer) ...[
                _gap(),
                CustomTextField(
                  controller: _github,
                  label: 'GitHub',
                  hint: 'https://github.com/...',
                  prefixIcon: Icons.terminal_rounded,
                  keyboardType: TextInputType.url,
                  validator: Validators.optionalUrl,
                ),
                const SizedBox(height: 20),
                const ResumeField(),
              ],
              const SizedBox(height: 24),
              CustomButton(
                text: 'Salvar alterações',
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
