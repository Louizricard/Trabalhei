import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../domain/plan_benefits.dart';

/// Tabela compacta Grátis × Pro.
class PlanComparisonTable extends StatelessWidget {
  final List<PlanRow> rows;

  const PlanComparisonTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.2),
          1: FlexColumnWidth(),
          2: FlexColumnWidth(),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          _row('Compare', 'Grátis', 'Pro', header: true),
          for (final r in rows) _row(r.label, r.free, r.pro),
        ],
      ),
    );
  }

  TableRow _row(String label, String free, String pro, {bool header = false}) {
    final weight = header ? FontWeight.w700 : FontWeight.w400;
    return TableRow(
      decoration: header
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borderDark)),
            )
          : null,
      children: [
        _cell(label, weight, TextAlign.start, AppColors.textSecondaryDark),
        _cell(free, weight, TextAlign.center, AppColors.textPrimaryDark),
        _cell(pro, FontWeight.w700, TextAlign.center, AppColors.primary),
      ],
    );
  }

  Widget _cell(String text, FontWeight weight, TextAlign align, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(fontSize: 13, fontWeight: weight, color: color),
      ),
    );
  }
}
