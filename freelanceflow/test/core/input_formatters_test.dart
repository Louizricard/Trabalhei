import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/core/utils/currency_formatter.dart';
import 'package:trabalhei/core/utils/input_formatters.dart';
import 'package:trabalhei/core/utils/validators.dart';

String type(TextInputFormatter f, String text, [String old = '']) => f
    .formatEditUpdate(TextEditingValue(text: old), TextEditingValue(text: text))
    .text;

void main() {
  group('CurrencyInputFormatter', () {
    const f = CurrencyInputFormatter();

    test('agrupa milhares e mantém centavos', () {
      expect(type(f, '1500'), '1.500');
      expect(type(f, '1500,5'), '1.500,5');
      expect(type(f, '1234567,891'), '1.234.567,89');
      expect(type(f, ',5'), '0,5');
      expect(type(f, '0012'), '12');
      expect(type(f, 'R\$ 2a0'), '20');
    });

    test('o texto formatado é lido pelo parser', () {
      for (final input in ['1500', '1500,5', '99999,99']) {
        expect(CurrencyFormatter.parse(type(f, input)), isNotNull);
      }
      expect(CurrencyFormatter.parse(type(f, '1500,50')), 1500.5);
    });

    test('recusa dígitos além do limite', () {
      expect(type(f, '123456789', '12.345.678'), '12.345.678');
    });
  });

  test('IntegerInputFormatter aceita só dígitos até o limite', () {
    const f = IntegerInputFormatter(maxDigits: 3);
    expect(type(f, '1a2'), '12');
    expect(type(f, '1234', '123'), '123');
  });

  test('CpfCnpjInputFormatter aplica a máscara certa', () {
    const f = CpfCnpjInputFormatter();
    expect(type(f, '12345678901'), '123.456.789-01');
    expect(type(f, '12345678000199'), '12.345.678/0001-99');
    expect(type(f, '1234'), '123.4');
  });

  group('Validators', () {
    test('minLength informa quanto falta', () {
      final v = Validators.minLength('o título', 10);
      expect(v(''), 'Informe o título.');
      expect(v('abc'), contains('faltam 7'));
      expect(v('título ok!!'), isNull);
    });

    test('money valida faixa e formato', () {
      final v = Validators.money(min: 10, max: 1000);
      expect(v(''), contains('Informe'));
      expect(v('5'), contains('mínimo'));
      expect(v('1.500'), contains('máximo'));
      expect(v('12,345'), contains('inválido'));
      expect(v('100,50'), isNull);
      expect(Validators.money(optional: true)(''), isNull);
    });

    test('intRange e links por domínio', () {
      expect(
        Validators.intRange(1, 365, unit: 'dias')('400'),
        contains('dias'),
      );
      expect(Validators.intRange(1, 365)('30'), isNull);
      final linkedin = Validators.optionalUrlFor('linkedin.com', 'x');
      expect(linkedin('linkedin.com/in/ana'), isNull);
      expect(linkedin('br.linkedin.com/in/ana'), isNull);
      expect(linkedin('github.com/ana'), contains('linkedin.com'));
      expect(linkedin(''), isNull);
    });
  });
}
