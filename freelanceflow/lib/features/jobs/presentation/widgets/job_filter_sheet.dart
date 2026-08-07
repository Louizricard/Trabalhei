import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../domain/entities/job.dart';
import '../../domain/repositories/job_repository.dart';
import '../providers/jobs_provider.dart';

class JobFilterSheet extends ConsumerStatefulWidget {
  const JobFilterSheet({super.key});

  @override
  ConsumerState<JobFilterSheet> createState() => _JobFilterSheetState();
}

class _JobFilterSheetState extends ConsumerState<JobFilterSheet> {
  late String _selectedCategory;
  late ExperienceLevel _selectedExp;
  late String _selectedSort;

  final _categories = ['Todas', 'Mobile', 'Web', 'Backend', 'Design', 'DevOps'];

  @override
  void initState() {
    super.initState();
    final filter = ref.read(jobFilterProvider);
    _selectedCategory = filter.category ?? 'Todas';
    _selectedExp = filter.experienceLevel ?? ExperienceLevel.all;
    _selectedSort = filter.sortBy;
  }

  void _applyFilter() {
    ref.read(jobFilterProvider.notifier).state = ref
        .read(jobFilterProvider)
        .copyWith(
          category: _selectedCategory == 'Todas' ? null : _selectedCategory,
          experienceLevel: _selectedExp,
          sortBy: _selectedSort,
        );
    Navigator.of(context).pop();
  }

  void _resetFilter() {
    ref.read(jobFilterProvider.notifier).state = const JobFilter();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filtros de Vagas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                TextButton(
                  onPressed: _resetFilter,
                  child: const Text(
                    'Limpar',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Category Filter
            const Text(
              'Categoria',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceElevatedDark,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.onPrimary
                        : AppColors.textSecondaryDark,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Experience Level Filter
            const Text(
              'Nível de Experiência',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildExpChip('Todos', ExperienceLevel.all),
                _buildExpChip('Júnior', ExperienceLevel.junior),
                _buildExpChip('Pleno', ExperienceLevel.pleno),
                _buildExpChip('Sênior', ExperienceLevel.senior),
              ],
            ),
            const SizedBox(height: 20),

            // Sort By
            const Text(
              'Ordenar por',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildSortChip('Mais recentes', 'recent'),
                _buildSortChip('Maior orçamento', 'budget_desc'),
                _buildSortChip('Menos propostas', 'proposals_asc'),
              ],
            ),
            const SizedBox(height: 28),

            CustomButton(
              text: 'Aplicar Filtros',
              onPressed: _applyFilter,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpChip(String label, ExperienceLevel level) {
    final isSelected = _selectedExp == level;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedExp = level),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceElevatedDark,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.onPrimary : AppColors.textSecondaryDark,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  Widget _buildSortChip(String label, String sort) {
    final isSelected = _selectedSort == sort;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedSort = sort),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceElevatedDark,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.onPrimary : AppColors.textSecondaryDark,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}
