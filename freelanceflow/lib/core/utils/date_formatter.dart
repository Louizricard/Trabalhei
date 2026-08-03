import 'package:intl/intl.dart';

class DateFormatter {
  static String relativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('dd/MM/yyyy', 'pt_BR').format(dateTime);
    } else if (difference.inDays >= 1) {
      return 'há ${difference.inDays} ${difference.inDays == 1 ? 'dia' : 'dias'}';
    } else if (difference.inHours >= 1) {
      return 'há ${difference.inHours} ${difference.inHours == 1 ? 'hora' : 'horas'}';
    } else if (difference.inMinutes >= 1) {
      return 'há ${difference.inMinutes} min';
    } else {
      return 'agora mesmo';
    }
  }

  static String simpleDate(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  static String timeOnly(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }
}
