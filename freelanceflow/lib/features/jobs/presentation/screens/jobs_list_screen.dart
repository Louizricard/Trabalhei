import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freelanceflow/core/theme/app_colors.dart';
import 'package:freelanceflow/core/widgets/empty_state.dart';
import 'package:freelanceflow/core/widgets/notification_bell_button.dart';
import 'package:freelanceflow/core/widgets/responsive_layout.dart';
import 'package:freelanceflow/features/auth/domain/entities/user_profile.dart';
import 'package:freelanceflow/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:freelanceflow/features/jobs/presentation/providers/jobs_provider.dart';
import 'package:freelanceflow/features/jobs/presentation/widgets/job_card.dart';
import 'package:go_router/go_router.dart';

class JobsListScreen extends ConsumerStatefulWidget {
  const JobsListScreen({super.key});

  @override
  ConsumerState<JobsListScreen> createState() => _JobsListScreenState();
}

class _JobsListScreenState extends ConsumerState<JobsListScreen> {
  final _searchController = TextEditingController();
  String? _selectedCategory;

  final _categories = ['Todos', 'Mobile', 'Design', 'Fullstack', 'Frontend', 'Backend', 'DevOps'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(jobsListProvider);
    final user = ref.watch(authProvider).value;
    final isClient = user?.role == UserRole.client;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mural de Vagas'),
        actions: [
          const NotificationBellButton(),
          if (isClient)
            Padding(
              padding: const EdgeInsets.only(right: 8, left: 4),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Publicar Vaga'),
                onPressed: () => context.push('/jobs/create'),
              ),
            ),
        ],
      ),
      body: ResponsiveLayout(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppColors.textPrimaryDark),
                decoration: InputDecoration(
                  hintText: 'Buscar vagas por título, tecnologia ou cliente...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondaryDark),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = (_selectedCategory == null && cat == 'Todos') || _selectedCategory == cat;

                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = cat == 'Todos' ? null : cat;
                      });
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surfaceElevatedDark,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.onPrimary : AppColors.textSecondaryDark,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.borderDark,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: jobsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => EmptyStateWidget(
                  icon: Icons.error_outline_rounded,
                  title: 'Erro ao carregar vagas',
                  description: err.toString(),
                ),
                data: (jobs) {
                  var filtered = jobs;
                  if (_selectedCategory != null) {
                    filtered = filtered.where((j) => j.category.toLowerCase() == _selectedCategory!.toLowerCase()).toList();
                  }
                  if (_searchController.text.isNotEmpty) {
                    final query = _searchController.text.toLowerCase();
                    filtered = filtered.where((j) => j.title.toLowerCase().contains(query) || j.skillsRequired.any((s) => s.toLowerCase().contains(query))).toList();
                  }

                  if (filtered.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.work_off_outlined,
                      title: 'Nenhuma vaga encontrada',
                      description: 'Tente alterar os filtros de busca ou volte mais tarde.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final job = filtered[index];
                      return JobCard(
                        job: job,
                        onTap: () => context.push('/jobs/${job.id}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
