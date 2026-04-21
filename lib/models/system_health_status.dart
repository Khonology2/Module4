enum SystemHealthLevel { healthy, degraded, critical, unknown }

class SystemHealthStatusModel {
  final SystemHealthLevel level;
  final String message;
  final DateTime checkedAt;
  final Map<String, double> resourceUsage;

  const SystemHealthStatusModel({
    required this.level,
    required this.message,
    required this.checkedAt,
    this.resourceUsage = const {},
  });

  bool get isHealthy => level == SystemHealthLevel.healthy;

  factory SystemHealthStatusModel.fromJson(Map<String, dynamic> json) {
    SystemHealthLevel parseLevel(dynamic value) {
      final raw = (value ?? '').toString().toLowerCase().trim();
      switch (raw) {
        case 'healthy':
          return SystemHealthLevel.healthy;
        case 'degraded':
          return SystemHealthLevel.degraded;
        case 'critical':
          return SystemHealthLevel.critical;
        default:
          return SystemHealthLevel.unknown;
      }
    }

    DateTime parseCheckedAt(dynamic value) {
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    final dynamic usageRaw = json['resourceUsage'];
    final usage = <String, double>{};
    if (usageRaw is Map) {
      for (final entry in usageRaw.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is num) {
          usage[key] = value.toDouble();
        } else if (value is String) {
          usage[key] = double.tryParse(value) ?? 0.0;
        } else {
          usage[key] = 0.0;
        }
      }
    }

    return SystemHealthStatusModel(
      level: parseLevel(json['level']),
      message: (json['message'] ?? 'No health message').toString(),
      checkedAt: parseCheckedAt(json['checkedAt']),
      resourceUsage: usage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level.name,
      'message': message,
      'checkedAt': checkedAt.toIso8601String(),
      'resourceUsage': resourceUsage,
    };
  }
}