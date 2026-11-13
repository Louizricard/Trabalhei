import 'package:flutter/material.dart';
import '../../../../../core/config/work_categories.dart';
import '../../../../../core/utils/input_formatters.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/widgets/category_picker.dart';
import '../../../../../core/widgets/field_label.dart';
import '../../../../../core/widgets/skills_input_widget.dart';
import '../../../domain/entities/profile_draft.dart';
import 'profile_form_parts.dart';

/// Nome, cidade e, para quem contrata, empresa e cargo.
class PersonalSection extends StatelessWidget {
  final ProfileDraft initial;
  final DraftEdit edit;
  final bool isFreelancer;

  const PersonalSection({
    super.key,
    required this.initial,
    required this.edit,
    required this.isFreelancer,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      title: 'Informações pessoais',
      description: 'Como você aparece para quem visita o seu perfil.',
      icon: Icons.person_outline_rounded,
      children: [
        DraftTextField(
          key: const Key('profile-name'),
          initialValue: initial.fullName,
          onChanged: (v) => edit((d) => d.copyWith(fullName: v)),
          label: 'Nome completo',
          requirement: FieldRequirement.required,
          prefixIcon: Icons.badge_outlined,
          maxLength: 120,
          validator: Validators.required('seu nome'),
        ),
        if (!isFreelancer) ...[
          DraftTextField(
            initialValue: initial.company,
            onChanged: (v) => edit((d) => d.copyWith(company: v)),
            label: 'Empresa',
            hint: 'Ex.: Padaria Pão Quente',
            prefixIcon: Icons.business_outlined,
            maxLength: 120,
          ),
          DraftTextField(
            initialValue: initial.headline,
            onChanged: (v) => edit((d) => d.copyWith(headline: v)),
            label: 'Cargo ou área',
            hint: 'Ex.: Sócia, gerente de marketing',
            prefixIcon: Icons.work_outline_rounded,
            maxLength: 80,
          ),
        ],
        DraftTextField(
          initialValue: initial.location,
          onChanged: (v) => edit((d) => d.copyWith(location: v)),
          label: 'Cidade',
          hint: 'Ex.: Goiânia, GO',
          prefixIcon: Icons.place_outlined,
          maxLength: 80,
        ),
      ],
    );
  }
}

/// Título, área do catálogo, valor por hora e habilidades (freelancer).
class ProfessionalSection extends StatelessWidget {
  final ProfileDraft initial;
  final ProfileDraft draft;
  final DraftEdit edit;

  const ProfessionalSection({
    super.key,
    required this.initial,
    required this.draft,
    required this.edit,
  });

  @override
  Widget build(BuildContext context) {
    final area = initial.category;
    return ProfileSectionCard(
      title: 'Profissional',
      description: 'O que você faz. Ajuda a mostrar vagas compatíveis.',
      icon: Icons.work_outline_rounded,
      children: [
        DraftTextField(
          initialValue: initial.headline,
          onChanged: (v) => edit((d) => d.copyWith(headline: v)),
          label: 'Título profissional',
          hint: 'Ex.: Designer de marcas, tradutora de inglês',
          prefixIcon: Icons.badge_outlined,
          maxLength: 80,
        ),
        CategoryPicker(
          initialValue: area == null
              ? null
              : (area: area, subcategory: initial.subcategory),
          label: 'Sua área principal',
          isRequired: false,
          onChanged: (c) => edit(
            (d) => d.copyWith(
              category: (area: c.area, subcategory: c.subcategory),
            ),
          ),
        ),
        DraftTextField(
          initialValue: initial.hourlyRate,
          onChanged: (v) => edit((d) => d.copyWith(hourlyRate: v)),
          label: 'Valor por hora',
          hint: '120,00',
          helperText:
              'Uma referência para clientes. Cada proposta tem o '
              'seu valor.',
          prefixText: r'R$ ',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [CurrencyInputFormatter()],
          validator: Validators.money(optional: true, max: 100000),
        ),
        SkillsInputWidget(
          initialValue: initial.skills,
          requirement: FieldRequirement.optional,
          maxSkills: 20,
          helperText: 'Até 20. Escolha uma sugestão ou digite e tecle Enter.',
          suggestions: WorkCategories.suggestedSkills(
            area: draft.category,
            subcategory: draft.subcategory,
          ),
          onChanged: (v) => edit((d) => d.copyWith(skills: v)),
        ),
      ],
    );
  }
}

/// Apresentação livre.
class AboutSection extends StatelessWidget {
  final ProfileDraft initial;
  final DraftEdit edit;
  final bool isFreelancer;

  const AboutSection({
    super.key,
    required this.initial,
    required this.edit,
    required this.isFreelancer,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      title: 'Apresentação',
      description: isFreelancer
          ? 'Experiência, especialidades e como você trabalha.'
          : 'Conte o que sua empresa faz e que tipo de trabalho costuma '
                'contratar.',
      icon: Icons.description_outlined,
      children: [
        DraftTextField(
          initialValue: initial.bio,
          onChanged: (v) => edit((d) => d.copyWith(bio: v)),
          label: 'Sobre você',
          maxLines: 6,
          maxLength: 2000,
        ),
      ],
    );
  }
}

/// Site, LinkedIn e, para freelancers, GitHub.
class LinksSection extends StatelessWidget {
  final ProfileDraft initial;
  final DraftEdit edit;
  final bool isFreelancer;

  const LinksSection({
    super.key,
    required this.initial,
    required this.edit,
    required this.isFreelancer,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      title: 'Links',
      description: 'Endereços completos, começando com https://.',
      icon: Icons.link_rounded,
      children: [
        DraftTextField(
          initialValue: initial.website,
          onChanged: (v) => edit((d) => d.copyWith(website: v)),
          label: isFreelancer ? 'Site ou portfólio' : 'Site da empresa',
          hint: 'https://',
          prefixIcon: Icons.language_rounded,
          keyboardType: TextInputType.url,
          validator: Validators.optionalUrl,
        ),
        DraftTextField(
          initialValue: initial.linkedin,
          onChanged: (v) => edit((d) => d.copyWith(linkedin: v)),
          label: 'LinkedIn',
          hint: 'https://www.linkedin.com/in/...',
          prefixIcon: Icons.work_outline_rounded,
          keyboardType: TextInputType.url,
          validator: Validators.optionalUrl,
        ),
        if (isFreelancer)
          DraftTextField(
            initialValue: initial.github,
            onChanged: (v) => edit((d) => d.copyWith(github: v)),
            label: 'GitHub',
            hint: 'https://github.com/...',
            helperText: 'Para quem trabalha com código.',
            prefixIcon: Icons.terminal_rounded,
            keyboardType: TextInputType.url,
            validator: Validators.optionalUrl,
          ),
      ],
    );
  }
}
