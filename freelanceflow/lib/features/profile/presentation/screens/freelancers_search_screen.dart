import 'package:trabalhei/core/errors/backend_errors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/freelancer_card.dart';
import '../widgets/freelancer_filter_modal.dart';
import '../widgets/invite_to_job_modal.dart';

class FreelancersSearchScreen extends ConsumerStatefulWidget {
  const FreelancersSearchScreen({super.key});

  @override
  ConsumerState<FreelancersSearchScreen> createState() =>
      _FreelancersSearchScreenState();
}

class _FreelancersSearchScreenState
    extends ConsumerState<FreelancersSearchScreen> {
  final _searchController = TextEditingController();

  final _skillsList = [
    'Todos',
    'Flutter',
    'React',
    'UI/UX',
    'Node.js',
    'Python',
    'Mobile',
    'Fullstack',
    'Frontend',
    'Backend',
    'DevOps',
    'Figma',
  ];

  @override
  void initState() {
    super.initState();
    final filter = ref.read(freelancerSearchFilterProvider);
    _searchController.text = filter.query;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    ref.read(freelancerSearchFilterProvider.notifier).setQuery(text);
  }

  @override
  Widget build(BuildContext context) {
    final freelancersAsync = ref.watch(freelancersListProvider);
    final filter = ref.watch(freelancerSearchFilterProvider);
    final currentUser = ref.watch(authProvider).value;
    final isClient = currentUser?.role == UserRole.client;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Talentos'),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.tune_rounded),
                if (filter.hasActiveFilters)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Filtros Avançados',
            onPressed: () => FreelancerFilterModal.show(context),
          ),
        ],
      ),
      body: ResponsiveLayout(
        child: Column(
          children: [
            // Barra de Pesquisa
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppColors.textPrimaryDark),
                decoration: InputDecoration(
                  hintText: 'Buscar por nome, cargo ou habilidades...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textMutedDark,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                ),
                onChanged: _onSearchChanged,
              ),
            ),

            // Chips Horizontais de Habilidades
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                itemCount: _skillsList.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final skill = _skillsList[index];
                  final isSelected =
                      (filter.skill == skill) ||
                      (filter.skill == null && skill == 'Todos') ||
                      (filter.skill == '' && skill == 'Todos');

                  return ChoiceChip(
                    label: Text(skill),
                    selected: isSelected,
                    onSelected: (_) {
                      ref
                          .read(freelancerSearchFilterProvider.notifier)
                          .setSkill(skill == 'Todos' ? null : skill);
                    },
                    selectedColor: AppColors.primaryContainer,
                    backgroundColor: AppColors.surfaceElevatedDark,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondaryDark,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.borderDark,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Listagem de Freelancers
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceDark,
                onRefresh: () async => ref.refresh(freelancersListProvider),
                child: freelancersAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  error: (err, _) => Center(
                    child: EmptyStateWidget(
                      icon: Icons.error_outline_rounded,
                      title: 'Erro ao carregar freelancers',
                      description: friendlyError(err),
                      actionText: 'Tentar novamente',
                      onAction: () => ref.refresh(freelancersListProvider),
                    ),
                  ),
                  data: (freelancers) {
                    if (freelancers.isEmpty) {
                      return Center(
                        child: EmptyStateWidget(
                          icon: Icons.people_outline_rounded,
                          title: 'Nenhum freelancer encontrado',
                          description:
                              'Tente ajustar os termos de busca ou limpar os filtros aplicados.',
                          actionText: filter.hasActiveFilters
                              ? 'Limpar Filtros'
                              : null,
                          onAction: filter.hasActiveFilters
                              ? () {
                                  _searchController.clear();
                                  ref
                                      .read(
                                        freelancerSearchFilterProvider.notifier,
                                      )
                                      .resetFilters();
                                }
                              : null,
                        ),
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 720;

                        if (isWide) {
                          return GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  mainAxisExtent: 250,
                                ),
                            itemCount: freelancers.length,
                            itemBuilder: (context, index) {
                              final f = freelancers[index];
                              return FreelancerCard(
                                freelancer: f,
                                onInvitePressed: isClient
                                    ? () => InviteToJobModal.show(context, f)
                                    : null,
                              );
                            },
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: freelancers.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final f = freelancers[index];
                            return FreelancerCard(
                              freelancer: f,
                              onInvitePressed: isClient
                                  ? () => InviteToJobModal.show(context, f)
                                  : null,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
