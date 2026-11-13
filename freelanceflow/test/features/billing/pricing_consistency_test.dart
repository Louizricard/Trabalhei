import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/features/billing/domain/entities/pricing.dart';

/// O banco é a fonte de verdade de preços e limites. O app e o site repetem
/// esses números como valor padrão e em textos fixos; este teste falha se um
/// deles mudar sem os outros (ver docs/monetizacao.md).
void main() {
  final migration = File(
    '../supabase/migrations/20261026162219_plans_and_limits.sql',
  ).readAsStringSync();
  final site = File('../site/index.html').readAsStringSync();

  int settingDefault(String column) {
    final match = RegExp(
      '$column integer not null default (\\d+)',
    ).firstMatch(migration);
    expect(match, isNotNull, reason: 'coluna $column não encontrada');
    return int.parse(match!.group(1)!);
  }

  ({double price, int days}) product(String code) {
    final match = RegExp(
      "\\('$code', '[^']+', ([\\d.]+), (\\d+)\\)",
    ).firstMatch(migration)!;
    return (
      price: double.parse(match.group(1)!),
      days: int.parse(match.group(2)!),
    );
  }

  test('padrões do app seguem platform_settings', () {
    const s = PlatformSettings();
    expect(s.freeMonthlyProposals, settingDefault('free_monthly_proposals'));
    expect(s.proMonthlyProposals, settingDefault('pro_monthly_proposals'));
    expect(s.dailyProposals, settingDefault('daily_proposals'));
    expect(s.minCoverLetterChars, settingDefault('min_cover_letter_chars'));
    expect(s.unansweredRefundDays, settingDefault('unanswered_refund_days'));
    expect(s.sponsoredSlots, settingDefault('sponsored_slots'));
    expect(
      s.sponsoredRotationMinutes,
      settingDefault('sponsored_rotation_minutes'),
    );
    expect(s.freeFileMb, settingDefault('free_file_mb'));
    expect(s.proFileMb, settingDefault('pro_file_mb'));
    expect(s.maxProposalTemplates, settingDefault('max_proposal_templates'));
  });

  test('preços padrão do app seguem billing_products', () {
    final pro = product('pro_monthly'), feature = product('job_feature');
    expect(Pricing.fallback.pro.price, pro.price);
    expect(Pricing.fallback.pro.periodDays, pro.days);
    expect(Pricing.fallback.feature.price, feature.price);
    expect(Pricing.fallback.feature.periodDays, feature.days);
  });

  test('números fixos do site seguem o banco', () {
    String brl(double v) => v.toStringAsFixed(2).replaceAll('.', ',');
    final pro = product('pro_monthly'), feature = product('job_feature');
    expect(site, contains('R\$ ${brl(pro.price)}'));
    expect(site, contains('R\$ ${brl(feature.price)}'));
    expect(site, contains('"price": "${feature.price.toStringAsFixed(2)}"'));
    expect(site, contains('${feature.days} dias'));
    expect(
      site,
      contains('${settingDefault('free_monthly_proposals')} propostas'),
    );
    expect(
      site,
      contains('${settingDefault('pro_monthly_proposals')} propostas'),
    );
    expect(site, contains('${settingDefault('daily_proposals')} propostas'));
    expect(site, contains('${settingDefault('pro_file_mb')} MB'));
    expect(site, contains('${settingDefault('unanswered_refund_days')} dias'));
  });
}
