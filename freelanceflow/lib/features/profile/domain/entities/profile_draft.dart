import '../../../auth/domain/entities/user_profile.dart';
import 'profile_update.dart';

/// Rascunho da edição de perfil. Comparado com o valor inicial, diz se há
/// alterações não salvas.
class ProfileDraft {
  final String fullName;
  final String headline;
  final String company;
  final String location;
  final String bio;
  final String hourlyRate;
  final List<String> skills;
  final String? category;
  final String? subcategory;
  final String website;
  final String linkedin;
  final String github;

  const ProfileDraft({
    this.fullName = '',
    this.headline = '',
    this.company = '',
    this.location = '',
    this.bio = '',
    this.hourlyRate = '',
    this.skills = const [],
    this.category,
    this.subcategory,
    this.website = '',
    this.linkedin = '',
    this.github = '',
  });

  factory ProfileDraft.fromUser(UserProfile u, {String rateText = ''}) =>
      ProfileDraft(
        fullName: u.fullName,
        headline: u.headline ?? '',
        company: u.companyName ?? '',
        location: u.location ?? '',
        bio: u.bio ?? '',
        hourlyRate: rateText,
        skills: List.unmodifiable(u.skills),
        category: u.category,
        subcategory: u.subcategory,
        website: u.websiteUrl ?? '',
        linkedin: u.linkedinUrl ?? '',
        github: u.githubUrl ?? '',
      );

  ProfileDraft copyWith({
    String? fullName,
    String? headline,
    String? company,
    String? location,
    String? bio,
    String? hourlyRate,
    List<String>? skills,
    ({String? area, String? subcategory})? category,
    String? website,
    String? linkedin,
    String? github,
  }) => ProfileDraft(
    fullName: fullName ?? this.fullName,
    headline: headline ?? this.headline,
    company: company ?? this.company,
    location: location ?? this.location,
    bio: bio ?? this.bio,
    hourlyRate: hourlyRate ?? this.hourlyRate,
    skills: skills == null ? this.skills : List.unmodifiable(skills),
    category: category == null ? this.category : category.area,
    subcategory: category == null ? subcategory : category.subcategory,
    website: website ?? this.website,
    linkedin: linkedin ?? this.linkedin,
    github: github ?? this.github,
  );

  /// [parseRate] converte o texto mascarado do valor/hora em número.
  ProfileUpdate toUpdate({
    required bool isFreelancer,
    required double? Function(String) parseRate,
  }) => ProfileUpdate(
    fullName: fullName,
    headline: headline,
    location: location,
    bio: bio,
    websiteUrl: website,
    linkedinUrl: linkedin,
    githubUrl: isFreelancer ? github : '',
    skills: skills,
    hourlyRate: isFreelancer ? parseRate(hourlyRate) ?? 0 : null,
    companyName: isFreelancer ? null : company,
    includeCategory: isFreelancer,
    category: category,
    subcategory: subcategory,
  );

  List<Object?> get _props => [
    fullName.trim(),
    headline.trim(),
    company.trim(),
    location.trim(),
    bio.trim(),
    hourlyRate.trim(),
    skills.join('\u0000'),
    category,
    subcategory,
    website.trim(),
    linkedin.trim(),
    github.trim(),
  ];

  @override
  bool operator ==(Object other) {
    if (other is! ProfileDraft) return false;
    final a = _props, b = other._props;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_props);
}
