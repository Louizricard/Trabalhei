import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freelanceflow/features/auth/domain/entities/user_profile.dart';
import 'package:freelanceflow/features/profile/domain/entities/portfolio_item.dart';
import 'package:freelanceflow/features/profile/presentation/providers/profile_provider.dart';
import 'package:freelanceflow/features/profile/presentation/widgets/freelancer_card.dart';

void main() {
  group('PortfolioItem Entity Tests', () {
    test('Should parse PortfolioItem from JSON correctly', () {
      final json = {
        'id': 'p-123',
        'title': 'E-commerce App',
        'description': 'Aplicativo mobile em Flutter com pagamentos integrados',
        'image_url': 'https://example.com/banner.png',
        'project_url': 'https://github.com/example/repo',
        'tags': ['Flutter', 'Riverpod', 'Supabase'],
      };

      final item = PortfolioItem.fromJson(json);

      expect(item.id, equals('p-123'));
      expect(item.title, equals('E-commerce App'));
      expect(item.description, contains('Aplicativo mobile'));
      expect(item.imageUrl, equals('https://example.com/banner.png'));
      expect(item.projectUrl, equals('https://github.com/example/repo'));
      expect(item.tags, equals(['Flutter', 'Riverpod', 'Supabase']));

      final serialized = item.toJson();
      expect(serialized['title'], equals('E-commerce App'));
      expect(serialized['tags'], equals(['Flutter', 'Riverpod', 'Supabase']));
    });
  });

  group('UserReview Entity Tests', () {
    test('Should parse UserReview with joined profile and job data', () {
      final json = {
        'id': 'rev-001',
        'rating': 5,
        'comment': 'Excelente desenvolvedor! Entregou antes do prazo com ótima qualidade.',
        'created_at': '2026-08-01T12:00:00Z',
        'profiles': {'full_name': 'Tech Corp'},
        'contracts': {
          'jobs': {'title': 'Aplicativo Delivery em Flutter'}
        },
      };

      final review = UserReview.fromJson(json);

      expect(review.id, equals('rev-001'));
      expect(review.authorName, equals('Tech Corp'));
      expect(review.projectTitle, equals('Aplicativo Delivery em Flutter'));
      expect(review.rating, equals(5.0));
      expect(review.comment, contains('Excelente desenvolvedor'));
    });
  });

  group('FreelancerSearchFilter Tests', () {
    test('Initial filter should have no active filters', () {
      const filter = FreelancerSearchFilter();
      expect(filter.hasActiveFilters, isFalse);
      expect(filter.orderBy, equals('rating_desc'));
    });

    test('Notifier should update filters and track active state', () {
      final notifier = FreelancerSearchFilterNotifier();

      notifier.setQuery('Flutter');
      expect(notifier.state.query, equals('Flutter'));

      notifier.setSkill('React');
      expect(notifier.state.skill, equals('React'));
      expect(notifier.state.hasActiveFilters, isTrue);

      notifier.updateFilters(
        minRating: 4.5,
        minHourlyRate: 50.0,
        maxHourlyRate: 150.0,
        availabilityStatus: 'available',
        orderBy: 'jobs_desc',
      );

      expect(notifier.state.minRating, equals(4.5));
      expect(notifier.state.minHourlyRate, equals(50.0));
      expect(notifier.state.maxHourlyRate, equals(150.0));
      expect(notifier.state.availabilityStatus, equals('available'));
      expect(notifier.state.orderBy, equals('jobs_desc'));
      expect(notifier.state.hasActiveFilters, isTrue);

      notifier.resetFilters();
      expect(notifier.state.hasActiveFilters, isFalse);
      expect(notifier.state.query, equals('Flutter')); // query is preserved
    });
  });

  group('FreelancerCard Widget Tests', () {
    testWidgets('Should display freelancer name, rating, rate and skills', (tester) async {
      final freelancer = UserProfile(
        id: 'f-1',
        email: 'ana@example.com',
        fullName: 'Ana Silva',
        role: UserRole.freelancer,
        bio: 'Especialista em Flutter e UI Design moderno.',
        hourlyRate: 95.0,
        skills: const ['Flutter', 'Dart', 'Figma'],
        rating: 4.9,
        completedJobsCount: 14,
        isVerified: true,
        availabilityStatus: 'available',
        createdAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FreelancerCard(freelancer: freelancer),
          ),
        ),
      );

      expect(find.text('Ana Silva'), findsOneWidget);
      expect(find.text('4.9'), findsOneWidget);
      expect(find.text('•  14 projetos'), findsOneWidget);
      expect(find.text('Flutter'), findsOneWidget);
      expect(find.text('Dart'), findsOneWidget);
      expect(find.text('Figma'), findsOneWidget);
      expect(find.text('Ver Perfil'), findsOneWidget);
    });
  });
}
