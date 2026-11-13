import '../../../../core/utils/validators.dart';

/// Campos que o usuário edita no próprio perfil. Texto vazio apaga o campo.
class ProfileUpdate {
  final String fullName;
  final String bio;
  final String headline;
  final String location;
  final String websiteUrl;
  final String linkedinUrl;
  final String githubUrl;
  final List<String> skills;
  final double? hourlyRate;

  /// Só para clientes; null deixa como está.
  final String? companyName;

  /// Área e especialidade do catálogo (freelancer). Só são gravadas com
  /// [includeCategory]; assim a edição de um cliente não apaga a área que
  /// ele tenha como freelancer.
  final bool includeCategory;
  final String? category;
  final String? subcategory;

  const ProfileUpdate({
    required this.fullName,
    this.bio = '',
    this.headline = '',
    this.location = '',
    this.websiteUrl = '',
    this.linkedinUrl = '',
    this.githubUrl = '',
    this.skills = const [],
    this.hourlyRate,
    this.companyName,
    this.includeCategory = false,
    this.category,
    this.subcategory,
  });

  static String? _orNull(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  Map<String, dynamic> toJson() => {
    'full_name': fullName.trim(),
    'bio': _orNull(bio),
    'headline': _orNull(headline),
    'location': _orNull(location),
    'website_url': _orNull(Validators.normalizeUrl(websiteUrl)),
    'linkedin_url': _orNull(Validators.normalizeUrl(linkedinUrl)),
    'github_url': _orNull(Validators.normalizeUrl(githubUrl)),
    'skills': skills,
    'hourly_rate': ?hourlyRate,
    if (companyName != null) 'company_name': _orNull(companyName!),
    if (includeCategory) ...{
      'category': category,
      'subcategory': category == null ? null : subcategory,
    },
  };
}
