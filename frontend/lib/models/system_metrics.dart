// System metrics data model
class SystemMetrics {
  final SystemHealthStatus systemHealth;
  final PerformanceMetrics performance;
  final DatabaseMetrics database;
  final UserActivityMetrics userActivity;
  final DateTime lastUpdated;

  SystemMetrics({
    required this.systemHealth,
    required this.performance,
    required this.database,
    required this.userActivity,
    required this.lastUpdated,
  });

  factory SystemMetrics.fromJson(Map<String, dynamic> json) {
    return SystemMetrics(
      systemHealth: SystemHealthStatus.values.firstWhere(
        (e) => e.toString() == 'SystemHealthStatus.\$${json['systemHealth']}',
        orElse: () => SystemHealthStatus.unknown,
      ),
      performance: PerformanceMetrics.fromJson(json['performance'] ?? {}),
      database: DatabaseMetrics.fromJson(json['database'] ?? {}),
      userActivity: UserActivityMetrics.fromJson(json['userActivity'] ?? {}),
      lastUpdated: DateTime.parse(json['lastUpdated'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'systemHealth': systemHealth.toString().split('.').last,
        'performance': performance.toJson(),
        'database': database.toJson(),
        'userActivity': userActivity.toJson(),
        'lastUpdated': lastUpdated.toIso8601String(),
      };
}

enum SystemHealthStatus {
  healthy,
  degraded,
  critical,
  unknown,
}

class PerformanceMetrics {
  final double cpuUsage;
  final double memoryUsage;
  final double diskUsage;
  final int responseTime;
  final double uptime;

  PerformanceMetrics({
    required this.cpuUsage,
    required this.memoryUsage,
    required this.diskUsage,
    required this.responseTime,
    required this.uptime,
  });

  factory PerformanceMetrics.fromJson(Map<String, dynamic> json) {
    return PerformanceMetrics(
      cpuUsage: (json['cpuUsage'] ?? 0.0).toDouble(),
      memoryUsage: (json['memoryUsage'] ?? 0.0).toDouble(),
      diskUsage: (json['diskUsage'] ?? 0.0).toDouble(),
      responseTime: (json['responseTime'] ?? 0).toInt(),
      uptime: (json['uptime'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'cpuUsage': cpuUsage,
        'memoryUsage': memoryUsage,
        'diskUsage': diskUsage,
        'responseTime': responseTime,
        'uptime': uptime,
      };
}

class DatabaseMetrics {
  final int totalRecords;
  final int activeConnections;
  final double cacheHitRatio;
  final int queryCount;
  final int slowQueries;

  DatabaseMetrics({
    required this.totalRecords,
    required this.activeConnections,
    required this.cacheHitRatio,
    required this.queryCount,
    required this.slowQueries,
  });

  factory DatabaseMetrics.fromJson(Map<String, dynamic> json) {
    return DatabaseMetrics(
      totalRecords: (json['totalRecords'] ?? 0).toInt(),
      activeConnections: (json['activeConnections'] ?? 0).toInt(),
      cacheHitRatio: (json['cacheHitRatio'] ?? 0.0).toDouble(),
      queryCount: (json['queryCount'] ?? 0).toInt(),
      slowQueries: (json['slowQueries'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'totalRecords': totalRecords,
        'activeConnections': activeConnections,
        'cacheHitRatio': cacheHitRatio,
        'queryCount': queryCount,
        'slowQueries': slowQueries,
      };
}

class UserActivityMetrics {
  final int activeUsers;
  final int totalSessions;
  final int newRegistrations;
  final int failedLogins;
  final double avgSessionDuration;

  UserActivityMetrics({
    required this.activeUsers,
    required this.totalSessions,
    required this.newRegistrations,
    required this.failedLogins,
    required this.avgSessionDuration,
  });

  factory UserActivityMetrics.fromJson(Map<String, dynamic> json) {
    return UserActivityMetrics(
      activeUsers: (json['activeUsers'] ?? 0).toInt(),
      totalSessions: (json['totalSessions'] ?? 0).toInt(),
      newRegistrations: (json['newRegistrations'] ?? 0).toInt(),
      failedLogins: (json['failedLogins'] ?? 0).toInt(),
      avgSessionDuration: (json['avgSessionDuration'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'activeUsers': activeUsers,
        'totalSessions': totalSessions,
        'newRegistrations': newRegistrations,
        'failedLogins': failedLogins,
        'avgSessionDuration': avgSessionDuration,
      };
}