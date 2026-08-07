class PortfolioItem {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String? projectUrl;
  final List<String> tags;

  const PortfolioItem({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    this.projectUrl,
    this.tags = const [],
  });

  factory PortfolioItem.fromJson(Map<String, dynamic> json) {
    return PortfolioItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      projectUrl: json['project_url'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'project_url': projectUrl,
      'tags': tags,
    };
  }
}

class UserReview {
  final String id;
  final String authorName;
  final String projectTitle;
  final double rating;
  final String comment;
  final DateTime createdAt;

  const UserReview({
    required this.id,
    required this.authorName,
    required this.projectTitle,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory UserReview.fromJson(Map<String, dynamic> json) {
    String author = 'Usuário';
    if (json['profiles'] is Map) {
      author = json['profiles']['full_name'] as String? ?? author;
    } else if (json['reviewer_name'] != null) {
      author = json['reviewer_name'] as String;
    }

    String project = 'Projeto';
    if (json['contracts'] is Map && json['contracts']['jobs'] is Map) {
      project = json['contracts']['jobs']['title'] as String? ?? project;
    }

    return UserReview(
      id: json['id'] as String,
      authorName: author,
      projectTitle: project,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      comment: json['comment'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
