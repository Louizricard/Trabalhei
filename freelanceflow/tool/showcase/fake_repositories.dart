import 'package:trabalhei/features/auth/domain/entities/user_profile.dart';
import 'package:trabalhei/features/auth/domain/repositories/auth_repository.dart';
import 'package:trabalhei/features/billing/data/billing_repository.dart';
import 'package:trabalhei/features/billing/domain/entities/billing.dart';
import 'package:trabalhei/features/chat/domain/entities/chat_message.dart';
import 'package:trabalhei/features/chat/domain/entities/conversation.dart';
import 'package:trabalhei/features/chat/domain/repositories/chat_repository.dart';
import 'package:trabalhei/features/jobs/domain/entities/job.dart';
import 'package:trabalhei/features/jobs/domain/repositories/job_repository.dart';
import 'package:trabalhei/features/notifications/domain/entities/app_notification.dart';
import 'package:trabalhei/features/notifications/domain/repositories/notification_repository.dart';
import 'package:trabalhei/features/profile/domain/entities/portfolio_item.dart';
import 'package:trabalhei/features/profile/domain/repositories/profile_repository.dart';
import 'package:trabalhei/features/proposals/domain/entities/proposal.dart';
import 'package:trabalhei/features/proposals/domain/entities/proposal_quota.dart';
import 'package:trabalhei/features/proposals/domain/repositories/proposal_repository.dart';
import 'demo_chat.dart';
import 'demo_data.dart';

// Repositórios em memória só com o que as telas leem. Ações (enviar, aceitar,
// pagar) não fazem parte dos prints e caem no noSuchMethod.

class FakeAuthRepository implements AuthRepository {
  final UserProfile user;
  FakeAuthRepository(this.user);

  @override
  Stream<UserProfile?> get authStateChanges => const Stream.empty();

  @override
  Future<UserProfile?> getCurrentUser() async => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeJobRepository implements JobRepository {
  @override
  Future<List<Job>> getJobs({JobFilter? filter}) async {
    final category = filter?.category;
    if (category == null || category == 'Todos') return demoJobs;
    return demoJobs.where((j) => j.category == category).toList();
  }

  @override
  Future<Job?> getJobById(String id) async =>
      demoJobs.where((j) => j.id == id).firstOrNull;

  @override
  Future<List<Job>> getClientJobs(String clientId) async =>
      demoJobs.where((j) => j.clientId == clientId).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeProposalRepository implements ProposalRepository {
  @override
  Future<List<Proposal>> getProposalsByJob(String jobId) async =>
      demoProposals.where((p) => p.jobId == jobId).toList();

  // O freelancer de demonstração ainda não se candidatou: a tela de proposta
  // abre em branco, pronta para ser preenchida.
  @override
  Future<List<Proposal>> getFreelancerProposals(String freelancerId) async =>
      [];

  @override
  Future<ProposalQuota> getQuota() async => const ProposalQuota(
    isPro: false,
    monthlyLimit: 10,
    used: 3,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeChatRepository implements ChatRepository {
  final bool viewerIsClient;
  FakeChatRepository({required this.viewerIsClient});

  @override
  Future<List<Conversation>> getConversations() async =>
      demoConversations(viewerIsClient: viewerIsClient);

  @override
  Future<Conversation?> getConversationById(String id) async =>
      demoConversations(
        viewerIsClient: viewerIsClient,
      ).where((c) => c.id == id).firstOrNull;

  @override
  Stream<List<ChatMessage>> getMessagesStream(String id) =>
      Stream.value(id == conversationId ? demoMessages() : []);

  @override
  Future<void> markConversationRead(String id) async {}

  @override
  Future<List<Map<String, dynamic>>> getMilestoneRevisions(String id) async =>
      [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeProfileRepository implements ProfileRepository {
  @override
  Future<UserProfile?> getProfileById(String userId) async =>
      [demoClient, ...demoFreelancers].where((u) => u.id == userId).firstOrNull;

  @override
  Future<List<UserReview>> getUserReviews(String userId) async => [];

  @override
  Future<List<PortfolioItem>> getPortfolioItems(String userId) async => [];

  @override
  Future<List<UserProfile>> searchFreelancers({
    String? query,
    String? skill,
    double? minRating,
    double? minHourlyRate,
    double? maxHourlyRate,
    String? availabilityStatus,
    String orderBy = 'rating_desc',
  }) async => demoFreelancers;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeNotificationRepository implements NotificationRepository {
  final String userId;
  FakeNotificationRepository(this.userId);

  @override
  Stream<List<AppNotification>> streamNotifications() =>
      Stream.value(demoNotifications(userId));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeBillingRepository implements BillingRepository {
  @override
  Future<Subscription?> getSubscription() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
