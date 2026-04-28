class VersionControl {
  static const String environment = 'PROD';
  
  static String generateVersionNumber({int releaseNumber = 1}) {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final release = releaseNumber.toString().padLeft(2, '0');
    
    return '$environment-$year-$month-$day-$release';
  }
  
  static Map<String, dynamic> getVersionInfo() {
    final now = DateTime.now();
    return {
      'version': generateVersionNumber(),
      'environment': environment,
      'year': now.year,
      'month': now.month,
      'day': now.day,
      'releaseNumber': 1,
      'timestamp': now.toIso8601String(),
      'weekNumber': _getWeekNumber(now),
      'dayOfWeek': now.weekday,
    };
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
- Week Number: ${info['weekNumber']}
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
