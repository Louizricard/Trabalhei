import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/field_label.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../providers/edit_profile_controller.dart';
import '../widgets/edit_profile/edit_profile_sections.dart';
import '../widgets/edit_profile/profile_form_parts.dart';
import '../widgets/resume_field.dart';

/// Edição do próprio perfil em página dedicada, organizada por seções.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sectionKeys = <String, GlobalKey>{};

  /// Perfil de quando a página abriu: o rascunho é comparado com ele, mesmo
  /// que o `authProvider` recarregue depois de salvar.
  UserProfile? _user;

  GlobalKey _keyFor(String section) =>
      _sectionKeys.putIfAbsent(section, GlobalKey.new);

  void _snack(String text, Color color) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(text), backgroundColor: color));

  void _leave() => context.canPop() ? context.pop() : context.go('/profile');

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text('O que você mudou nesta página não foi salvo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Continuar editando'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _tryLeave(bool dirty) async {
    if (!dirty || await _confirmDiscard()) {
      if (mounted) _leave();
    }
  }

  Future<void> _save(EditProfileController controller) async {
    // Tirar o foco grava o texto pendente das habilidades antes de validar.
    FocusScope.of(context).unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!(_formKey.currentState?.validate() ?? false)) {
      _snack('Revise os campos destacados.', AppColors.error);
      return;
    }
    try {
      await controller.save();
      if (!mounted) return;
      _snack('Perfil atualizado!', AppColors.success);
      _leave();
    } catch (e) {
      if (mounted) {
        _snack('Não foi possível salvar: ${friendlyError(e)}', AppColors.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user ??= ref.watch(authProvider).valueOrNull;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final provider = editProfileControllerProvider(user);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final isFreelancer = user.role == UserRole.freelancer;
    final DraftEdit edit = controller.edit;

    final sections = <(String, Widget)>[
      (
        'Informações pessoais',
        PersonalSection(
          initial: state.initial,
          edit: edit,
          isFreelancer: isFreelancer,
        ),
      ),
      if (isFreelancer)
        (
          'Profissional',
          ProfessionalSection(
            initial: state.initial,
            draft: state.draft,
            edit: edit,
          ),
        ),
      (
        'Apresentação',
        AboutSection(
          initial: state.initial,
          edit: edit,
          isFreelancer: isFreelancer,
        ),
      ),
      (
        'Links',
        LinksSection(
          initial: state.initial,
          edit: edit,
          isFreelancer: isFreelancer,
        ),
      ),
      if (isFreelancer)
        (
          'Currículo',
          const ProfileSectionCard(
            title: 'Currículo',
            description: 'Enviar, trocar ou remover vale na hora.',
            icon: Icons.picture_as_pdf_outlined,
            children: [ResumeField()],
          ),
        ),
    ];

    final form = Form(
      key: _formKey,
      child: FocusTraversalGroup(
        // Coluna (e não ListView) para o índice achar seções fora da tela.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const RequiredFieldsNote(),
              const SizedBox(height: 12),
              for (final (name, widget) in sections) ...[
                KeyedSubtree(key: _keyFor(name), child: widget),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );

    return PopScope(
      canPop: !state.isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _tryLeave(true);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Editar perfil'),
          leading: IconButton(
            tooltip: 'Voltar',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => _tryLeave(state.isDirty),
          ),
        ),
        body: ResponsiveLayout(
          maxWidth: 1000,
          child: LayoutBuilder(
            builder: (context, c) => c.maxWidth < 840
                ? form
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionIndex(
                        names: [for (final (n, _) in sections) n],
                        onTap: (n) => Scrollable.ensureVisible(
                          _keyFor(n).currentContext!,
                          duration: const Duration(milliseconds: 300),
                        ),
                      ),
                      Expanded(child: form),
                    ],
                  ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: CustomButton(
              key: const Key('profile-save'),
              text: 'Salvar alterações',
              icon: Icons.check_rounded,
              width: double.infinity,
              isLoading: state.saving,
              onPressed: () => _save(controller),
            ),
          ),
        ),
      ),
    );
  }
}

/// Índice lateral das seções (telas largas).
class _SectionIndex extends StatelessWidget {
  final List<String> names;
  final ValueChanged<String> onTap;

  const _SectionIndex({required this.names, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Padding(
        padding: const EdgeInsets.only(top: 16, left: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final n in names)
              TextButton(
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  foregroundColor: AppColors.textSecondaryDark,
                ),
                onPressed: () => onTap(n),
                child: Text(n),
              ),
          ],
        ),
      ),
    );
  }
}
