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
  };
}
