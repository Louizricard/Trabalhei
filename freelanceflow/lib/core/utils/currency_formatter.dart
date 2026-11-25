import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatBRL = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  static String format(double amount) {
    return _formatBRL.format(amount);
  }

  static String formatRange(double min, double max) {
    return '${_formatBRL.format(min)} - ${_formatBRL.format(max)}';
  }

  static final NumberFormat _input = NumberFormat('#,##0.00', 'pt_BR');

  /// Texto para preencher um campo de valor ("1.500,00"), no mesmo formato
  /// que o campo mostra depois de digitado e lido de volta por [parse].
  static String toInput(double amount) => _input.format(amount);

  /// Completa o que foi digitado no formato de reais ("1500" vira
  /// "1.500,00"). Entradas que não são um valor ficam como estão, para o
  /// validador explicar o problema.
  static String normalizeInput(String text) {
    final amount = parse(text);
    return amount == null ? text : toInput(amount);
  }

  static final RegExp _thousands = RegExp(r'^\d{1,3}(\.\d{3})+$');
  static final RegExp _plain = RegExp(r'^\d+$');
  static final RegExp _commaDecimal = RegExp(
    r'^(\d+|\d{1,3}(\.\d{3})+),\d{1,2}$',
  );
  static final RegExp _dotDecimal = RegExp(r'^\d+\.\d{1,2}$');

  /// Lê um valor digitado em reais ("1.500,50", "1500,50", "1.500",
  /// "1500.50", com ou sem "R$"). Devolve null quando a entrada é inválida,
  /// negativa ou ambígua ("1,500,000", "12,345"), para o formulário recusar
  /// em vez de salvar um valor errado.
  static double? parse(String? input) {
    final text = (input ?? '').replaceAll('R\$', '').replaceAll(' ', '').trim();
    if (text.isEmpty) return null;
    String normalized;
    if (_plain.hasMatch(text)) {
      normalized = text;
    } else if (_thousands.hasMatch(text)) {
      normalized = text.replaceAll('.', '');
    } else if (_commaDecimal.hasMatch(text)) {
      normalized = text.replaceAll('.', '').replaceAll(',', '.');
    } else if (_dotDecimal.hasMatch(text)) {
      normalized = text;
    } else {
      return null;
    }
    return double.tryParse(normalized);
  }
}
