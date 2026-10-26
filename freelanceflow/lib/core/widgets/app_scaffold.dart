import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/entities/user_profile.dart';
import '../../features/auth/presentation/guest_access.dart';
import '../../features/auth/presentation/providers/auth_state_provider.dart';
import '../theme/app_colors.dart';

class AppScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppScaffold({super.key, required this.navigationShell});

  /// O que cada aba faz, para o aviso a visitantes (a aba de vagas é livre).
  static const _guestActions = [
    '',
    'ver suas mensagens',
    'acompanhar seus projetos no painel',
    'montar seu perfil',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.valueOrNull;
    final isClient = user?.role == UserRole.client;
    final isGuest = !auth.isLoading && user == null;

    void selectTab(int index) {
      if (isGuest && index != 0) {
        requireAccount(context, ref, action: _guestActions[index]);
        return;
      }
      navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );
    }

    final navItems = [
      const NavigationDestination(
        icon: Icon(Icons.work_outline_rounded),
        selectedIcon: Icon(Icons.work_rounded),
        label: 'Vagas',
      ),
      const NavigationDestination(
        icon: Icon(Icons.chat_bubble_outline_rounded),
        selectedIcon: Icon(Icons.chat_bubble_rounded),
        label: 'Mensagens',
      ),
      NavigationDestination(
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard_rounded),
        label: isClient ? 'Contratante' : 'Painel',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Perfil',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Wide screen (Desktop / Web)
        if (constraints.maxWidth >= 840) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: selectTab,
                  backgroundColor: AppColors.surfaceDark,
                  selectedIconTheme: const IconThemeData(
                    color: AppColors.primary,
                  ),
                  selectedLabelTextStyle: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelTextStyle: const TextStyle(
                    color: AppColors.textMutedDark,
                    fontWeight: FontWeight.w500,
                  ),
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 16,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/icons/app_logo.png',
                            width: 30,
                            height: 30,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Trabalhei',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: AppColors.textPrimaryDark,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: isGuest ? const _GuestRailActions() : null,
                  labelType: NavigationRailLabelType.all,
                  destinations: navItems
                      .map(
                        (item) => NavigationRailDestination(
                          icon: item.icon,
                          selectedIcon: item.selectedIcon,
                          label: Text(item.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(
                  thickness: 1,
                  width: 1,
                  color: AppColors.borderDark,
                ),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }

        // Mobile Screen
        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: selectTab,
            backgroundColor: AppColors.surfaceDark,
            indicatorColor: AppColors.primaryContainer,
            destinations: navItems,
          ),
        );
      },
    );
  }
}

/// Entrar e criar conta no menu lateral, para visitantes.
class _GuestRailActions extends StatelessWidget {
  const _GuestRailActions();

  @override
  Widget build(BuildContext context) {
    final from = GoRouter.of(context).state.uri.toString();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          FilledButton(
            onPressed: () =>
                context.go(authRouteReturningTo('/register', from)),
            child: const Text('Criar conta'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go(authRouteReturningTo('/login', from)),
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
  }
}
