import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/core/utils/date_formatter.dart';

void main() {
  setUpAll(DateFormatter.initialize);

  test('formata vagas antigas após a inicialização usada pelo app', () {
    expect(DateFormatter.relativeTime(DateTime(2000, 1, 2)), '02/01/2000');
  });

  test('preserva datas relativas de vagas recentes', () {
    final now = DateTime.now();
    expect(DateFormatter.relativeTime(now), 'agora mesmo');
    expect(
      DateFormatter.relativeTime(now.subtract(const Duration(days: 6))),
      'há 6 dias',
    );
    expect(
      DateFormatter.relativeTime(now.subtract(const Duration(days: 7))),
      'há 7 dias',
    );
    final older = now.subtract(const Duration(days: 8));
    expect(DateFormatter.relativeTime(older), DateFormatter.simpleDate(older));
  });
}
