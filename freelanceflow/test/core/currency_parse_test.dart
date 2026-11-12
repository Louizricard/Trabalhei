import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter.parse aceita os formatos brasileiros', () {
    const cases = <String, double>{
      '1500': 1500,
      '1500,50': 1500.5,
      '1.500': 1500,
      '1.500,50': 1500.5,
      '1.500.000': 1500000,
      '1.500.000,99': 1500000.99,
      '1500.50': 1500.5,
      '1500.5': 1500.5,
      'R\$ 2.000,00': 2000,
      ' 80 ': 80,
      '0,99': 0.99,
    };
    cases.forEach((input, expected) {
      test('"$input" → $expected', () {
        expect(CurrencyFormatter.parse(input), expected);
      });
    });
  });

  group('CurrencyFormatter.parse recusa entradas ambíguas ou inválidas', () {
    for (final input in [
      '',
      '   ',
      'abc',
      '1,500,000',
      '1.50.0',
      '12,345',
      '-100',
      '1..5',
      ',',
      'R\$',
    ]) {
      test('"$input" → null', () {
        expect(CurrencyFormatter.parse(input), isNull);
      });
    }
    test('null → null', () => expect(CurrencyFormatter.parse(null), isNull));
  });
}
