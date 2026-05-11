class VersionControl {
  static const String environment = String.fromEnvironment(
    'APP_ENVIRONMENT',
    defaultValue: 'SIT',
  );
  static const int commitCountOverride = int.fromEnvironment(
    'VERSION_COMMIT_COUNT',
    defaultValue: 1,
  );

  static String generateVersionNumber({int? commitCount}) {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final weekLetter = _getWeekLetter(now);
    final dayLetter = _getDayLetter(now);
    final effectiveCommitCount = _resolveCommitCount(now, commitCount);

    // Format: Ver 2026.03AB5 SIT
    return 'Ver $year.$month$weekLetter$dayLetter$effectiveCommitCount $environment';
  }

  static Map<String, dynamic> getVersionInfo() {
    final now = DateTime.now();
    final weekLetter = _getWeekLetter(now);
    final dayLetter = _getDayLetter(now);
    final effectiveCommitCount = _resolveCommitCount(now, null);
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    return {
      'version': generateVersionNumber(commitCount: effectiveCommitCount),
      'versionCode': '$year.$month$weekLetter$dayLetter$effectiveCommitCount',
      'environment': environment,
      'year': now.year,
      'month': now.month,
      'day': now.day,
      'weekLetter': weekLetter,
      'dayLetter': dayLetter,
      'commitCount': effectiveCommitCount,
      'timestamp': now.toIso8601String(),
      'weekNumber': _getWeekNumber(now),
      'dayOfWeek': now.weekday,
    };
  }

  static int _resolveCommitCount(DateTime now, int? commitCount) {
    final candidate = commitCount ?? commitCountOverride;
    // Do not count weekend pushes toward this number.
    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      return 0;
    }
    return candidate < 0 ? 0 : candidate;
  }

  static String _getWeekLetter(DateTime date) {
    // 4-week cycle in a month: A, B, C, D.
    final week = ((date.day - 1) ~/ 7) + 1;
    if (week <= 1) return 'A';
    if (week == 2) return 'B';
    if (week == 3) return 'C';
    return 'D';
  }

  static String _getDayLetter(DateTime date) {
    // Mon=A, Tue=B, Wed=C, Thu=D, Fri=E, weekends keep E.
    switch (date.weekday) {
      case DateTime.monday:
        return 'A';
      case DateTime.tuesday:
        return 'B';
      case DateTime.wednesday:
        return 'C';
      case DateTime.thursday:
        return 'D';
      default:
        return 'E';
    }
  }

  static int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysDifference = date.difference(firstDayOfYear).inDays;
    return ((daysDifference + firstDayOfYear.weekday - 1) / 7).floor() + 1;
  }

  static String getFormattedVersionInfo() {
    final info = getVersionInfo();
    return '''
Version Information:
- Version: ${info['version']}
- Environment: ${info['environment']}
- Date: ${info['year']}-${info['month'].toString().padLeft(2, '0')}-${info['day'].toString().padLeft(2, '0')}
- Week Number: ${info['weekNumber']} (${info['weekLetter']})
- Day Letter: ${info['dayLetter']}
- Commit Count: ${info['commitCount']}
''';
  }

  static bool isProductionEnvironment() {
    return environment == 'PROD';
  }

  static bool isStagingEnvironment() {
    return environment == 'UAT';
  }

  static bool isDevelopmentEnvironment() {
    return environment == 'DEV' || environment == 'SIT';
  }
}
