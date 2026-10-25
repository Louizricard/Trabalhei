import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trabalhei/core/theme/app_theme.dart';
import 'package:trabalhei/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:trabalhei/features/billing/presentation/providers/billing_provider.dart';
import 'package:trabalhei/features/chat/presentation/providers/chat_provider.dart';
import 'package:trabalhei/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:trabalhei/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:trabalhei/features/jobs/presentation/providers/jobs_provider.dart';
import 'package:trabalhei/features/notifications/presentation/providers/notification_provider.dart';
import 'package:trabalhei/features/profile/presentation/providers/profile_provider.dart';
import 'package:trabalhei/features/proposals/presentation/providers/proposals_provider.dart';
import 'package:trabalhei/main.dart';
import 'demo_data.dart';
import 'fake_repositories.dart';

/// App real com dados fictícios, para gerar os prints da homepage.
///
/// flutter build web -t tool/showcase/main.dart --base-href /
/// Abra `/?role=client#/chat/demo-conv-1` (ou `role=freelancer`, padrão).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Endereço inválido de propósito: nada sai do navegador.
  await Supabase.initialize(
    url: 'https://showcase.invalid',
    publishableKey: 'showcase',
  );

  await AppTheme.preloadFonts();

  final isClient = Uri.base.queryParameters['role'] == 'client';
  final user = isClient ? demoClient : demoFreelancer;

  runApp(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(user)),
        jobRepositoryProvider.overrideWithValue(FakeJobRepository()),
        proposalRepositoryProvider.overrideWithValue(FakeProposalRepository()),
        chatRepositoryProvider.overrideWithValue(
          FakeChatRepository(viewerIsClient: isClient),
        ),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        notificationRepositoryProvider.overrideWithValue(
          FakeNotificationRepository(user.id),
        ),
        billingRepositoryProvider.overrideWithValue(FakeBillingRepository()),
        freelancerStatsProvider.overrideWith(
          (ref) async => const FreelancerDashboardStats(
            activeContractsCount: 2,
            completedContractsCount: 9,
            pendingProposalsCount: 3,
            sentProposalsCount: 18,
            acceptedProposalsCount: 7,
            monthlyCompleted: [1, 2, 1, 3, 1, 2],
          ),
        ),
        clientStatsProvider.overrideWith(
          (ref) async => const ClientDashboardStats(
            activeJobsCount: 1,
            activeContractsCount: 2,
            completedContractsCount: 4,
            unreviewedProposalsCount: 3,
            monthlyCompleted: [0, 1, 1, 0, 2, 1],
          ),
        ),
      ],
      child: const TrabalheiApp(),
    ),
  );
}
