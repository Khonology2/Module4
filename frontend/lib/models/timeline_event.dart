import 'package:flutter/material.dart';

enum TimelineEventType {
  milestone,
  task,
  meeting,
  deliverable,
  review,
  deployment,
  other,
}

class TimelineEvent {
  final String id;
  final String title;
  final String description;
  final TimelineEventType type;
  final DateTime? date;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? projectId;
  final String? sprintId;
  final String? deliverableId;
  final String? assignedTo;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> metadata;
  final bool isCompleted;

  // Legacy fields used by the original rich timeline screen.
  // These are optional and primarily for backwards-compatibility.
  final String? time; // Format: "HH:mm"
  final String? priority; // 'low' | 'medium' | 'high'
  final String? project;
  final String? colorTag; // 'red' | 'blue' | 'green' | 'orange' | 'purple'

  const TimelineEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.date,
    this.startTime,
    this.endTime,
    this.projectId,
    this.sprintId,
    this.deliverableId,
    this.assignedTo,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.metadata = const {},
    this.isCompleted = false,
    this.time,
    this.priority,
    this.project,
    this.colorTag,
  });

  TimelineEvent copyWith({
    String? id,
    String? title,
    String? description,
    TimelineEventType? type,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
    String? projectId,
    String? sprintId,
    String? deliverableId,
    String? assignedTo,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
    bool? isCompleted,
    String? time,
    String? priority,
    String? project,
    String? colorTag,
  }) {
    return TimelineEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      projectId: projectId ?? this.projectId,
      sprintId: sprintId ?? this.sprintId,
      deliverableId: deliverableId ?? this.deliverableId,
      assignedTo: assignedTo ?? this.assignedTo,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
      isCompleted: isCompleted ?? this.isCompleted,
      time: time ?? this.time,
      priority: priority ?? this.priority,
      project: project ?? this.project,
      colorTag: colorTag ?? this.colorTag,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'date': date?.toIso8601String(),
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'projectId': projectId,
      'sprintId': sprintId,
      'deliverableId': deliverableId,
      'assignedTo': assignedTo,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'metadata': metadata,
      'isCompleted': isCompleted,
      'time': time,
      'priority': priority,
      'project': project,
      'colorTag': colorTag,
    };
  }

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    return TimelineEvent(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: TimelineEventType.values.firstWhere(
        (e) => e.name == json['type']?.toString(),
        orElse: () => TimelineEventType.other,
      ),
      date: json['date'] != null ? DateTime.parse(json['date'].toString()) : null,
      startTime: json['startTime'] != null ? DateTime.parse(json['startTime'].toString()) : null,
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime'].toString()) : null,
      projectId: json['projectId']?.toString(),
      sprintId: json['sprintId']?.toString(),
      deliverableId: json['deliverableId']?.toString(),
      assignedTo: json['assignedTo']?.toString(),
      createdBy: json['createdBy']?.toString(),
      createdAt: DateTime.parse(json['createdAt']?.toString() ?? DateTime.now().toIso8601String()),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'].toString()) : null,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      isCompleted: json['isCompleted'] ?? false,
      time: json['time']?.toString(),
      priority: json['priority']?.toString(),
      project: json['project']?.toString(),
      colorTag: json['colorTag']?.toString(),
    );
  }

  /// Backwards-compatible convenience getter matching the original model.
  DateTime get dateTime => date ?? startTime ?? createdAt;

  String get typeDisplayName {
    switch (type) {
      case TimelineEventType.milestone:
        return 'Milestone';
      case TimelineEventType.task:
        return 'Task';
      case TimelineEventType.meeting:
        return 'Meeting';
      case TimelineEventType.deliverable:
        return 'Deliverable';
      case TimelineEventType.review:
        return 'Review';
      case TimelineEventType.deployment:
        return 'Deployment';
      case TimelineEventType.other:
        return 'Other';
    }
  }

  Color get typeColor {
    switch (type) {
      case TimelineEventType.milestone:
        return Colors.purple;
      case TimelineEventType.task:
        return Colors.blue;
      case TimelineEventType.meeting:
        return Colors.green;
      case TimelineEventType.deliverable:
        return Colors.orange;
      case TimelineEventType.review:
        return Colors.red;
      case TimelineEventType.deployment:
        return Colors.teal;
      case TimelineEventType.other:
        return Colors.grey;
    }
  }

  IconData get typeIcon {
    switch (type) {
      case TimelineEventType.milestone:
        return Icons.flag;
      case TimelineEventType.task:
        return Icons.task;
      case TimelineEventType.meeting:
        return Icons.groups;
      case TimelineEventType.deliverable:
        return Icons.inventory_2;
      case TimelineEventType.review:
        return Icons.rate_review;
      case TimelineEventType.deployment:
        return Icons.cloud_upload;
      case TimelineEventType.other:
        return Icons.event;
    }
  }

  bool get isOverdue {
    if (date == null || isCompleted) return false;
    return DateTime.now().isAfter(date!);
  }

  bool get isToday {
    if (date == null) return false;
    final now = DateTime.now();
    return date!.year == now.year && date!.month == now.month && date!.day == now.day;
  }

  bool get isUpcoming {
    if (date == null || isCompleted) return false;
    return date!.isAfter(DateTime.now());
  }

  String get formattedDate {
    if (date == null) return 'No date';
    return '${date!.day}/${date!.month}/${date!.year}';
  }

  String get formattedTime {
    if (startTime == null) return '';
    return '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}';
  }

  String get formattedDateTime {
    if (date == null) return 'No date';
    final dateStr = formattedDate;
    final timeStr = formattedTime;
    return timeStr.isNotEmpty ? '$dateStr at $timeStr' : dateStr;
  }

  int get daysUntil {
    if (date == null) return -1;
    return date!.difference(DateTime.now()).inDays;
  }

  Map<String, dynamic> get auditMetadata {
    return {
      'eventId': id,
      'eventTitle': title,
      'eventType': type.name,
      'action': 'timeline_event_updated',
      'timestamp': DateTime.now().toIso8601String(),
      'projectId': projectId,
      'isCompleted': isCompleted,
      'eventDate': date?.toIso8601String(),
    };
  }
}

extension TimelineEventTypeExtension on TimelineEventType {
  String get displayName {
    switch (this) {
      case TimelineEventType.milestone:
        return 'Milestone';
      case TimelineEventType.task:
        return 'Task';
      case TimelineEventType.meeting:
        return 'Meeting';
      case TimelineEventType.deliverable:
        return 'Deliverable';
      case TimelineEventType.review:
        return 'Review';
      case TimelineEventType.deployment:
        return 'Deployment';
      case TimelineEventType.other:
        return 'Other';
    }
  }

  Color get color {
    switch (this) {
      case TimelineEventType.milestone:
        return Colors.purple;
      case TimelineEventType.task:
        return Colors.blue;
      case TimelineEventType.meeting:
        return Colors.green;
      case TimelineEventType.deliverable:
        return Colors.orange;
      case TimelineEventType.review:
        return Colors.red;
      case TimelineEventType.deployment:
        return Colors.teal;
      case TimelineEventType.other:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case TimelineEventType.milestone:
        return Icons.flag;
      case TimelineEventType.task:
        return Icons.task;
      case TimelineEventType.meeting:
        return Icons.groups;
      case TimelineEventType.deliverable:
        return Icons.inventory_2;
      case TimelineEventType.review:
        return Icons.rate_review;
      case TimelineEventType.deployment:
        return Icons.cloud_upload;
      case TimelineEventType.other:
        return Icons.event;
    }
  }
}
