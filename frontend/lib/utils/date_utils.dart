import 'package:intl/intl.dart';

class DateUtils {
  static final DateFormat _uiDateTimeFormat = DateFormat('d MMM yyyy, h:mm a');
  static final DateFormat _uiDateFormat = DateFormat('d MMM yyyy');
  static final DateFormat _uiTimeFormat = DateFormat('h:mm a');

  /// Formats a DateTime object into a string like "10 Apr 2026, 12:00 AM"
  static String formatDateTime(DateTime date) {
    return _uiDateTimeFormat.format(date);
  }

  /// Formats a DateTime object into a date string like "10 Apr 2026"
  static String formatDate(DateTime date) {
    return _uiDateFormat.format(date);
  }

  /// Formats a DateTime object into a time string like "2:30 PM"
  static String formatTime(DateTime date) {
    return _uiTimeFormat.format(date);
  }

  /// Formats a DateTime object into a numeric date string like "2023-10-24"
  static String formatIsoDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Parses a raw database timestamp string and formats it to a readable format
  /// Input: "2026-04-10 00:00:00.000" -> Output: "10 Apr 2026"
  static String formatDatabaseTimestamp(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) {
      return 'N/A';
    }

    try {
      final dateTime = DateTime.parse(timestamp);
      return formatDate(dateTime);
    } catch (e) {
      return timestamp;
    }
  }

  /// Parses a raw database timestamp string and formats it with time
  /// Input: "2026-04-10 14:30:00.000" -> Output: "10 Apr 2026, 2:30 PM"
  static String formatDatabaseTimestampWithTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) {
      return 'N/A';
    }

    try {
      final dateTime = DateTime.parse(timestamp);
      return formatDateTime(dateTime);
    } catch (e) {
      return timestamp;
    }
  }

  /// Formats a timestamp string that might be in various formats
  /// Handles both DateTime objects and string timestamps
  static String formatTimestamp(dynamic timestamp) {
    if (timestamp == null) {
      return 'N/A';
    }

    if (timestamp is DateTime) {
      return formatDate(timestamp);
    }

    if (timestamp is String) {
      return formatDatabaseTimestamp(timestamp);
    }

    return 'N/A';
  }

  /// Formats a timestamp string that might be in various formats with time
  /// Handles both DateTime objects and string timestamps
  static String formatTimestampWithTime(dynamic timestamp) {
    if (timestamp == null) {
      return 'N/A';
    }

    if (timestamp is DateTime) {
      return formatDateTime(timestamp);
    }

    if (timestamp is String) {
      return formatDatabaseTimestampWithTime(timestamp);
    }

    return 'N/A';
  }
}
