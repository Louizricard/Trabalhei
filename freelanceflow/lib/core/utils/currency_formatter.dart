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
}
