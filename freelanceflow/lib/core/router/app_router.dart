import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_client.dart';
import '../../features/auth/domain/entities/user_profile.dart';
import '../../features/auth/presentation/providers/auth_state_provider.dart';
import '../../features/auth/presentation/providers/password_recovery_provider.dart';
import '../../features/auth/presentation/providers/pending_confirmation_provider.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/email_confirmation_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/chat/presentation/screens/chat_list_screen.dart';
import '../../features/chat/presentation/screens/chat_room_screen.dart';
import '../../features/dashboard/presentation/screens/client_dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/freelancer_dashboard_screen.dart';
import '../../features/jobs/presentation/screens/create_job_screen.dart';
import '../../features/jobs/presentation/screens/job_detail_screen.dart';
import '../../features/jobs/domain/entities/job.dart';
import '../../features/jobs/presentation/providers/jobs_provider.dart';
import '../../features/jobs/presentation/screens/jobs_list_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/billing/presentation/screens/plans_screen.dart';
import '../../features/profile/presentation/screens/freelancers_search_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/public_profile_screen.dart';
import '../../features/profile/presentation/screens/terms_and_privacy_screen.dart';
import '../../features/proposals/presentation/screens/apply_job_screen.dart';
import '../../features/proposals/presentation/screens/job_proposals_screen.dart';
import '../errors/backend_errors.dart';
import '../widgets/app_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _jobsNavigatorKey = GlobalKey<NavigatorState>();
final _chatNavigatorKey = GlobalKey<NavigatorState>();
final _dashNavigatorKey = GlobalKey<NavigatorState>();
final _profileNavigatorKey = GlobalKey<NavigatorState>();

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  StreamSubscription<AuthState>? _recoverySub;

  RouterNotifier(this._ref) {
    // Link de redefinição aberto no mesmo navegador que pediu (fluxo PKCE).
    _recoverySub = _ref
        .read(supabaseClientProvider)
        .auth
        .onAuthStateChange
        .listen((state) {
          if (state.event == AuthChangeEvent.passwordRecovery) {
            _ref.read(passwordRecoveryProvider.notifier).state = true;
            notifyListeners();
          }
        }, onError: (Object _) {});
    _ref.listen(authProvider, (_, next) {
      // Entrou: o e-mail está confirmado e o aviso de cadastro pendente some.
      if (next.valueOrNull != null) {
        _ref.read(pendingConfirmationProvider.notifier).clear();
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _recoverySub?.cancel();
    super.dispose();
  }
}

final routerNotifierProvider = Provider<RouterNotifier>(
  (ref) => RouterNotifier(ref),
);

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      // valueOrNull: em estado de erro, `.value` lança e trava toda a navegação.
      final isLoggedIn = authState.valueOrNull != null;
      final loc = state.matchedLocation;

      // Links de e-mail do Supabase (confirmação/recuperação) chegam como
      // fragmento na URL; o SDK já processa a sessão, então só tratamos a rota.
      final raw = state.uri.toString();
      if (raw.contains('error_code=')) {
        final expired = raw.contains('otp_expired');
        return '/login?notice=${Uri.encodeComponent(expired ? 'O link do e-mail expirou ou já foi usado. Entre com sua senha ou peça um novo link.' : 'Não foi possível validar o link do e-mail.')}';
      }
      if (raw.contains('access_token=') || raw.contains('type=signup')) {
        return '/jobs';
      }
      final isAuthRoute =
          loc == '/splash' ||
          loc == '/login' ||
          loc == '/register' ||
          loc == '/confirm-email' ||
          loc == '/forgot-password' ||
          loc == '/reset-password' ||
          loc == '/terms';

      if (loc == '/splash') return null;

      if (authState.isLoading) return null;

      if (isLoggedIn &&
          ref.read(passwordRecoveryProvider) &&
          loc != '/reset-password') {
        return '/reset-password';
      }

      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      if (isLoggedIn && (loc == '/login' || loc == '/register')) {
        return '/jobs';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            LoginScreen(notice: state.uri.queryParameters['notice']),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/confirm-email',
        builder: (context, state) => EmailConfirmationScreen(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/terms',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TermsAndPrivacyScreen(),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/plans',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PlansScreen(),
      ),
      GoRoute(
        path: '/freelancers',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const FreelancersSearchScreen(),
      ),
      GoRoute(
        path: '/jobs/create',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateJobScreen(),
      ),
      GoRoute(
        path: '/jobs/:id/edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => _EditJobLoader(
          jobId: state.pathParameters['id']!,
          initial: state.extra as Job?,
        ),
      ),
      GoRoute(
        path: '/jobs/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            JobDetailScreen(jobId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/jobs/:id/proposals',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            JobProposalsScreen(jobId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/jobs/:id/apply',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            ApplyJobScreen(jobId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/profile/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            PublicProfileScreen(userId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chat/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            ChatRoomScreen(conversationId: state.pathParameters['id']!),
      ),

      // Stateful Shell with 4 Navigation Branches
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppScaffold(navigationShell: navigationShell);
        },
        branches: [
          // Branch 1: Jobs
          StatefulShellBranch(
            navigatorKey: _jobsNavigatorKey,
            routes: [
              GoRoute(
                path: '/jobs',
                builder: (context, state) =>
                    JobsListScreen(initialCategory: state.extra as String?),
              ),
            ],
          ),

          // Branch 2: Chat
          StatefulShellBranch(
            navigatorKey: _chatNavigatorKey,
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => const ChatListScreen(),
              ),
            ],
          ),

          // Branch 3: Dashboard
          StatefulShellBranch(
            navigatorKey: _dashNavigatorKey,
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const _DashboardSwitcher(),
              ),
            ],
          ),

          // Branch 4: Profile
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _DashboardSwitcher extends ConsumerWidget {
  const _DashboardSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    if (user?.role == UserRole.client) {
      return const ClientDashboardScreen();
    }
    return const FreelancerDashboardScreen();
  }
}

/// Carrega a vaga pelo id quando a rota é aberta sem `extra` (reload/deep link).
class _EditJobLoader extends ConsumerWidget {
  final String jobId;
  final Job? initial;

  const _EditJobLoader({required this.jobId, this.initial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initial != null) return CreateJobScreen(jobToEdit: initial);
    final jobAsync = ref.watch(jobDetailProvider(jobId));
    return jobAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(friendlyError(e))),
      ),
      data: (job) => job == null
          ? Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Vaga não encontrada.')),
            )
          : CreateJobScreen(jobToEdit: job),
    );
  }
}
