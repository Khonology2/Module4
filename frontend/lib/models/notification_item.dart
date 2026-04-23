enum NotificationType {
  approval,
  deliverable,
  sprint,
  repository,
  system,
  team,
  file,
  reportSubmission,      // Report submitted for review
  reportApproved,        // Report approved by client
  reportChangesRequested, // Changes requested on report
}

enum NotificationAction {
  approvalRequest,
  approvalReminder,
  approvalApproved,
  approvalRejected,
  deliverableCreated,
  deliverableUpdated,
  sprintStarted,
  sprintCompleted,
  systemError,
  general,
}

class NotificationItem {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final bool isRead;
  final NotificationType type;
  final String message;
  final DateTime timestamp;
  final NotificationAction action;
  final String? relatedId;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.isRead,
    required this.type,
    required this.message,
    required this.timestamp,
    this.action = NotificationAction.general,
    this.relatedId,
  });

  NotificationItem copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    bool? isRead,
    NotificationType? type,
    String? message,
    DateTime? timestamp,
    NotificationAction? action,
    String? relatedId,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      action: action ?? this.action,
      relatedId: relatedId ?? this.relatedId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'isRead': isRead,
      'type': type.name,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'action': action.name,
      'relatedId': relatedId,
    };
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    NotificationType parseType(String? typeString) {
      if (typeString == null) return NotificationType.system;
      final typeMap = {
        'report_submission': NotificationType.reportSubmission,
        'report_approved': NotificationType.reportApproved,
        'report_changes_requested': NotificationType.reportChangesRequested,
      };
      if (typeMap.containsKey(typeString)) {
        return typeMap[typeString]!;
      }
      try {
        return NotificationType.values.firstWhere(
          (e) => e.name == typeString,
          orElse: () => NotificationType.system,
        );
      } catch (_) {
        return NotificationType.system;
      }
    }
    NotificationAction parseAction(String? actionString) {
      if (actionString == null) return NotificationAction.general;
      try {
        return NotificationAction.values.firstWhere(
          (e) => e.name == actionString,
          orElse: () => NotificationAction.general,
        );
      } catch (_) {
        return NotificationAction.general;
      }
    }
    final createdAt = json['createdAt'] ?? json['created_at'] ?? json['date'] ?? json['timestamp'];
    DateTime parseDate(dynamic v) {
      try {
        return v is String ? DateTime.parse(v) : (v is DateTime ? v : DateTime.now());
      } catch (_) {
        return DateTime.now();
      }
    }
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      title: (json['title'] ?? 'Notification').toString(),
      description: (json['description'] ?? json['message'] ?? '').toString(),
      date: parseDate(createdAt),
      isRead: (json['isRead'] ?? json['is_read'] ?? false) == true,
      type: parseType(json['type']?.toString()),
      message: (json['message'] ?? '').toString(),
      timestamp: parseDate(createdAt),
      action: parseAction(json['action']?.toString()),
      relatedId: json['relatedId']?.toString(),
    );
  }
}
