import 'package:intl/intl.dart';

class DateUtils {
  /// Formats a DateTime object into a string like "Oct 24, 2023 2:30 PM"
  static String formatDateTime(DateTime date) {
    return DateFormat('MMM d, yyyy h:mm a').format(date);
  }

  /// Formats a DateTime object into a date string like "Oct 24, 2023"
  static String formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  /// Formats a DateTime object into a time string like "2:30 PM"
  static String formatTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }
  
  /// Formats a DateTime object into a numeric date string like "2023-10-24"
  static String formatIsoDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }
}
