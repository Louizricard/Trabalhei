import 'package:flutter/services.dart';

/// Máscaras de digitação compartilhadas pelos formulários.
///
/// Todas mantêm o cursor no fim do texto: são usadas em campos curtos, em que
/// editar no meio é raro, e isso evita saltos de cursor ao reformatar.
TextEditingValue _atEnd(String text) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: text.length),
);

String _groupThousands(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Valor em reais no formato brasileiro: "1.500" ou "1.500,50".
///
/// A pessoa digita só números (e a vírgula, se quiser centavos); os pontos de
/// milhar entram sozinhos. O texto resultante é lido por
/// `CurrencyFormatter.parse`.
class CurrencyInputFormatter extends TextInputFormatter {
  /// Quantidade máxima de dígitos da parte inteira (8 = até R$ 99.999.999).
  final int maxIntegerDigits;

  const CurrencyInputFormatter({this.maxIntegerDigits = 8});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(RegExp(r'[^0-9,]'), '');
    if (raw.isEmpty) return _atEnd('');
    final comma = raw.indexOf(',');
    var integer = comma < 0 ? raw : raw.substring(0, comma);
    var cents = comma < 0 ? null : raw.substring(comma + 1).replaceAll(',', '');
    integer = integer.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (integer.length > maxIntegerDigits) return oldValue;
    if (integer.isEmpty && cents != null) integer = '0';
    if (cents != null && cents.length > 2) cents = cents.substring(0, 2);
    final text = _groupThousands(integer) + (cents == null ? '' : ',$cents');
    return _atEnd(text);
  }
}

/// Apenas números inteiros, com no máximo [maxDigits] dígitos.
class IntegerInputFormatter extends TextInputFormatter {
  final int maxDigits;

  const IntegerInputFormatter({this.maxDigits = 4});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > maxDigits) return oldValue;
    return _atEnd(digits);
  }
}

/// CPF (000.000.000-00) ou CNPJ (00.000.000/0000-00), conforme a quantidade
/// de dígitos.
class CpfCnpjInputFormatter extends TextInputFormatter {
  const CpfCnpjInputFormatter();

  static String mask(String digits) {
    const cpf = '###.###.###-##';
    const cnpj = '##.###.###/####-##';
    final pattern = digits.length <= 11 ? cpf : cnpj;
    final buffer = StringBuffer();
    var i = 0;
    for (final char in pattern.split('')) {
      if (i >= digits.length) break;
      if (char == '#') {
        buffer.write(digits[i++]);
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 14) return oldValue;
    return _atEnd(mask(digits));
  }
}
