import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/entities/user_profile.dart';
import '../../features/auth/presentation/providers/auth_state_provider.dart';
import '../theme/app_colors.dart';

class AppScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final isClient = user?.role == UserRole.client;

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
                  onDestinationSelected: (index) => navigationShell.goBranch(
                    index,
                    initialLocation: index == navigationShell.currentIndex,
                  ),
                  backgroundColor: AppColors.surfaceDark,
                  selectedIconTheme: const IconThemeData(color: AppColors.primaryLight),
                  selectedLabelTextStyle: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold),
                  unselectedLabelTextStyle: const TextStyle(color: AppColors.textSecondaryDark),
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.rocket_launch_rounded, color: AppColors.primary, size: 28),
                        SizedBox(width: 8),
                        Text(
                          'FreelanceFlow',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimaryDark),
                        ),
                      ],
                    ),
                  ),
                  labelType: NavigationRailLabelType.all,
                  destinations: navItems
                      .map((item) => NavigationRailDestination(
                            icon: item.icon,
                            selectedIcon: item.selectedIcon,
                            label: Text(item.label),
                          ))
                      .toList(),
                ),
                const VerticalDivider(thickness: 1, width: 1),
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
            onDestinationSelected: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            backgroundColor: AppColors.surfaceDark,
            indicatorColor: AppColors.primary.withAlpha(50),
            destinations: navItems,
          ),
        );
      },
    );
  }
}
