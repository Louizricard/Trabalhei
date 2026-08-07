import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/custom_button.dart';
import '../providers/profile_provider.dart';

class FreelancerFilterModal extends ConsumerStatefulWidget {
  const FreelancerFilterModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const FreelancerFilterModal(),
    );
  }

  @override
  ConsumerState<FreelancerFilterModal> createState() =>
      _FreelancerFilterModalState();
}

class _FreelancerFilterModalState extends ConsumerState<FreelancerFilterModal> {
  late double _minRating;
  late RangeValues _hourlyRateRange;
  late String _availability;
  late String _orderBy;

  @override
  void initState() {
    super.initState();
    final filter = ref.read(freelancerSearchFilterProvider);
    _minRating = filter.minRating ?? 0.0;
    _hourlyRateRange = RangeValues(
      filter.minHourlyRate ?? 0.0,
      filter.maxHourlyRate ?? 300.0,
    );
    _availability = filter.availabilityStatus ?? 'all';
    _orderBy = filter.orderBy;
  }

  void _apply() {
    ref
        .read(freelancerSearchFilterProvider.notifier)
        .updateFilters(
          minRating: _minRating > 0 ? _minRating : null,
          minHourlyRate: _hourlyRateRange.start > 0
              ? _hourlyRateRange.start
              : null,
          maxHourlyRate: _hourlyRateRange.end < 300
              ? _hourlyRateRange.end
              : null,
          availabilityStatus: _availability != 'all' ? _availability : null,
          orderBy: _orderBy,
        );
    Navigator.of(context).pop();
  }

  void _reset() {
    ref.read(freelancerSearchFilterProvider.notifier).resetFilters();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filtros de Busca',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryDark,
                  letterSpacing: -0.3,
                ),
              ),
              TextButton(
                onPressed: _reset,
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

          // 1. Ordenação
          const Text(
            'Ordenar por',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChoiceChip(
                'Melhor Avaliados',
                'rating_desc',
                _orderBy,
                (v) => setState(() => _orderBy = v),
              ),
              _buildChoiceChip(
                'Mais Projetos',
                'jobs_desc',
                _orderBy,
                (v) => setState(() => _orderBy = v),
              ),
              _buildChoiceChip(
                'Menor Valor/h',
                'rate_asc',
                _orderBy,
                (v) => setState(() => _orderBy = v),
              ),
              _buildChoiceChip(
                'Maior Valor/h',
                'rate_desc',
                _orderBy,
                (v) => setState(() => _orderBy = v),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Avaliação Mínima
          const Text(
            'Avaliação Mínima',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildRatingChip('Todas', 0.0),
              const SizedBox(width: 8),
              _buildRatingChip('★ 4.0+', 4.0),
              const SizedBox(width: 8),
              _buildRatingChip('★ 4.5+', 4.5),
              const SizedBox(width: 8),
              _buildRatingChip('★ 4.8+', 4.8),
            ],
          ),
          const SizedBox(height: 20),

          // 3. Faixa de Valor/Hora
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Valor por Hora',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              Text(
                '${CurrencyFormatter.format(_hourlyRateRange.start)} - ${_hourlyRateRange.end >= 300 ? "R\$ 300+" : CurrencyFormatter.format(_hourlyRateRange.end)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          RangeSlider(
            values: _hourlyRateRange,
            min: 0,
            max: 300,
            divisions: 30,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.surfaceElevatedDark,
            onChanged: (vals) => setState(() => _hourlyRateRange = vals),
          ),
          const SizedBox(height: 12),

          // 4. Disponibilidade
          const Text(
            'Disponibilidade',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildChoiceChip(
                'Todos',
                'all',
                _availability,
                (v) => setState(() => _availability = v),
              ),
              const SizedBox(width: 8),
              _buildChoiceChip(
                'Disponível Agora',
                'available',
                _availability,
                (v) => setState(() => _availability = v),
              ),
              const SizedBox(width: 8),
              _buildChoiceChip(
                'Ocupado',
                'busy',
                _availability,
                (v) => setState(() => _availability = v),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Botão Aplicar
          CustomButton(text: 'Aplicar Filtros', onPressed: _apply),
        ],
      ),
    );
  }

  Widget _buildChoiceChip(
    String label,
    String value,
    String selectedValue,
    ValueChanged<String> onSelected,
  ) {
    final isSelected = value == selectedValue;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: AppColors.primaryContainer,
      backgroundColor: AppColors.surfaceElevatedDark,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppColors.primary : AppColors.textSecondaryDark,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.borderDark,
        ),
      ),
    );
  }

  Widget _buildRatingChip(String label, double ratingValue) {
    final isSelected = _minRating == ratingValue;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _minRating = ratingValue),
      selectedColor: AppColors.primaryContainer,
      backgroundColor: AppColors.surfaceElevatedDark,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppColors.primary : AppColors.textSecondaryDark,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.borderDark,
        ),
      ),
    );
  }
}
