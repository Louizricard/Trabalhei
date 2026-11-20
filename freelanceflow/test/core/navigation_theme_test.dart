import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/core/theme/app_colors.dart';
import 'package:trabalhei/core/theme/app_theme.dart';

/// Contraste WCAG entre duas cores opacas.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final rail = AppTheme.navigationRailTheme;
  final bar = AppTheme.navigationBarTheme;

  test('barra lateral não cai no secondaryContainer opaco', () {
    expect(rail.indicatorColor, AppColors.navIndicator);
    expect(rail.indicatorColor!.a, lessThan(0.5));
  });

  test('ícone ativo legível sobre a pílula, nas duas barras', () {
    // Pílula translúcida composta sobre o fundo da barra.
    final pill = Color.alphaBlend(AppColors.navIndicator, AppColors.surfaceDark);
    final railIcon = rail.selectedIconTheme!.color!;
    final barIcon = bar.iconTheme!.resolve({WidgetState.selected})!.color!;
    expect(railIcon, barIcon);
    expect(_contrast(railIcon, pill), greaterThanOrEqualTo(4.5));
  });

  test('ícone inativo legível sobre a barra e diferente do ativo', () {
    final idle = rail.unselectedIconTheme!.color!;
    expect(idle, isNot(rail.selectedIconTheme!.color));
    expect(_contrast(idle, AppColors.surfaceDark), greaterThanOrEqualTo(3));
    expect(bar.iconTheme!.resolve({})!.color, idle);
  });

  test('hover e foco têm realce sutil', () {
    final overlay = bar.overlayColor!;
    expect(overlay.resolve({WidgetState.hovered}), AppColors.navHover);
    expect(overlay.resolve({WidgetState.focused}), AppColors.navHover);
    expect(overlay.resolve({WidgetState.pressed}), AppColors.navPressed);
  });
}
