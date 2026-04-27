import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum ProjectStatus {
  planning,
  active,
  onHold,
  completed,
  cancelled,
}

enum ProjectPriority {
  low,
  medium,
  high,
  critical,
}

enum ProjectRole {
  owner,
  contributor,
  viewer,
}

class ProjectMember {
  final String userId;
  final String userName;
  final String userEmail;
  final ProjectRole role;
  final DateTime assignedAt;

  const ProjectMember({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.role,
    required this.assignedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'role': role.name,
      'assignedAt': assignedAt.toIso8601String(),
    };
  }

  factory ProjectMember.fromJson(Map<String, dynamic> json) {
    return ProjectMember(
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      userEmail: json['userEmail']?.toString() ?? '',
      role: ProjectRole.values.firstWhere(
        (e) => e.name == json['role']?.toString(),
        orElse: () => ProjectRole.viewer,
      ),
      assignedAt: DateTime.parse(
          json['assignedAt']?.toString() ?? DateTime.now().toIso8601String()),
    );
  }
}

class Project {
  final String id;
  final String name;
  final String key;
  final String description;
  final String? clientName;
  final String? clientOwnerName;
  final ProjectStatus status;
  final ProjectPriority priority;
  final String projectType;
  final DateTime startDate;
  final DateTime? endDate;
  final List<String> tags;
  final List<ProjectMember> members;
  final List<String> deliverableIds;
  final List<String> sprintIds;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? updatedBy;
  final String? ownerId;
  final Map<String, dynamic> metadata;

  const Project({
    required this.id,
    required this.name,
    required this.key,
    required this.description,
    this.clientName,
    this.clientOwnerName,
    required this.status,
    required this.priority,
    required this.projectType,
    required this.startDate,
    this.endDate,
    this.tags = const [],
    this.members = const [],
    this.deliverableIds = const [],
    this.sprintIds = const [],
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.updatedBy,
    this.ownerId,
    this.metadata = const {},
  });

  Project copyWith({
    String? id,
    String? name,
    String? key,
    String? description,
    String? clientName,
    String? clientOwnerName,
    ProjectStatus? status,
    ProjectPriority? priority,
    String? projectType,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? tags,
    List<ProjectMember>? members,
    List<String>? deliverableIds,
    List<String>? sprintIds,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? updatedBy,
    String? ownerId,
    Map<String, dynamic>? metadata,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      key: key ?? this.key,
      description: description ?? this.description,
      clientName: clientName ?? this.clientName,
      clientOwnerName: clientOwnerName ?? this.clientOwnerName,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      projectType: projectType ?? this.projectType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      tags: tags ?? this.tags,
      members: members ?? this.members,
      deliverableIds: deliverableIds ?? this.deliverableIds,
      sprintIds: sprintIds ?? this.sprintIds,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      ownerId: ownerId ?? this.ownerId,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'key': key,
      'description': description,
      'clientName': clientName,
      'client_name': clientName,
      'clientOwnerName': clientOwnerName,
      'client_owner_name': clientOwnerName,
      'status': status.name,
      'priority': priority.name,
      'projectType': projectType,
      'project_type': projectType,
      'startDate': startDate.toIso8601String(),
      'start_date': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'tags': tags,
      'members': members.map((m) => m.toJson()).toList(),
      'deliverableIds': deliverableIds,
      'deliverable_ids': deliverableIds,
      'sprintIds': sprintIds,
      'sprint_ids': sprintIds,
      'createdBy': createdBy,
      'created_by': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'updatedBy': updatedBy,
      'updated_by': updatedBy,
      'ownerId': ownerId,
      'owner_id': ownerId,
      'metadata': metadata,
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    String? asString(dynamic value) {
      return value?.toString();
    }

    List<String> asStringList(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return [];
    }

    final startStr =
        asString(json['startDate']) ?? asString(json['start_date']);
    final endStr = asString(json['endDate']) ?? asString(json['end_date']);
    final createdAtStr =
        asString(json['createdAt']) ?? asString(json['created_at']);
    final updatedAtStr =
        asString(json['updatedAt']) ?? asString(json['updated_at']);

    return Project(
      id: asString(json['id']) ?? '',
      name: asString(json['name']) ?? '',
      key: asString(json['key'] ?? json['projectKey'] ?? json['project_key']) ??
          '',
      description: asString(json['description']) ?? '',
      clientName: asString(json['clientName'] ?? json['client_name']),
      clientOwnerName:
          asString(json['clientOwnerName'] ?? json['client_owner_name']),
      status: ProjectStatus.values.firstWhere(
        (e) => e.name == asString(json['status']),
        orElse: () => ProjectStatus.planning,
      ),
      priority: ProjectPriority.values.firstWhere(
        (e) => e.name == asString(json['priority']),
        orElse: () => ProjectPriority.medium,
      ),
      projectType:
          asString(json['projectType'] ?? json['project_type']) ?? 'software',
      startDate: startStr != null && startStr.isNotEmpty
          ? DateTime.parse(startStr)
          : DateTime.now(),
      endDate:
          endStr != null && endStr.isNotEmpty ? DateTime.parse(endStr) : null,
      tags: asStringList(json['tags']),
      members: (json['members'] as List<dynamic>?)
              ?.map((m) => ProjectMember.fromJson(Map<String, dynamic>.from(m)))
              .toList() ??
          [],
      deliverableIds:
          asStringList(json['deliverableIds'] ?? json['deliverable_ids']),
      sprintIds: asStringList(json['sprintIds'] ?? json['sprint_ids']),
      createdBy: asString(json['createdBy'] ?? json['created_by']) ?? '',
      createdAt: createdAtStr != null && createdAtStr.isNotEmpty
          ? DateTime.parse(createdAtStr)
          : DateTime.now(),
      updatedAt: updatedAtStr != null && updatedAtStr.isNotEmpty
          ? DateTime.parse(updatedAtStr)
          : null,
      updatedBy: asString(json['updatedBy'] ?? json['updated_by']),
      ownerId: asString(json['ownerId']) ??
          asString(json['owner_id']) ??
          (json['owner'] != null && json['owner'] is Map
              ? asString((json['owner'] as Map)['id'])
              : null),
      metadata: json['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['metadata'] as Map<String, dynamic>)
          : (json['metadata'] is Map
              ? Map<String, dynamic>.from(json['metadata'] as Map)
              : <String, dynamic>{}),
    );
  }

  String get statusDisplayName {
    switch (status) {
      case ProjectStatus.planning:
        return 'Planning';
      case ProjectStatus.active:
        return 'Active';
      case ProjectStatus.onHold:
        return 'On Hold';
      case ProjectStatus.completed:
        return 'Completed';
      case ProjectStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get priorityDisplayName {
    switch (priority) {
      case ProjectPriority.low:
        return 'Low';
      case ProjectPriority.medium:
        return 'Medium';
      case ProjectPriority.high:
        return 'High';
      case ProjectPriority.critical:
        return 'Critical';
    }
  }

  Color get statusColor {
    switch (status) {
      case ProjectStatus.planning:
        return Colors.blue;
      case ProjectStatus.active:
        return Colors.green;
      case ProjectStatus.onHold:
        return Colors.orange;
      case ProjectStatus.completed:
        return Colors.purple;
      case ProjectStatus.cancelled:
        return Colors.red;
    }
  }

  Color get priorityColor {
    switch (priority) {
      case ProjectPriority.low:
        return Colors.grey;
      case ProjectPriority.medium:
        return Colors.blue;
      case ProjectPriority.high:
        return Colors.orange;
      case ProjectPriority.critical:
        return Colors.red;
    }
  }

  bool get isOverdue {
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!) &&
        status != ProjectStatus.completed;
  }

  int get daysUntilEnd {
    if (endDate == null) return -1;
    return endDate!.difference(DateTime.now()).inDays;
  }

  bool get isActive {
    return status == ProjectStatus.active;
  }

  List<ProjectMember> get owners {
    return members.where((m) => m.role == ProjectRole.owner).toList();
  }

  List<ProjectMember> get contributors {
    return members.where((m) => m.role == ProjectRole.contributor).toList();
  }

  List<ProjectMember> get viewers {
    return members.where((m) => m.role == ProjectRole.viewer).toList();
  }

  int get totalMembers => members.length;

  bool hasMember(String userId) {
    return members.any((m) => m.userId == userId);
  }

  ProjectMember? getMember(String userId) {
    try {
      return members.firstWhere((m) => m.userId == userId);
    } catch (e) {
      return null;
    }
  }

  String get formattedEndDate {
    if (endDate == null) return 'No end date';
    return DateFormat('d MMM yyyy').format(endDate!);
  }

  String get formattedStartDate {
    return DateFormat('d MMM yyyy').format(startDate);
  }

  Map<String, dynamic> get auditMetadata {
    return {
      'projectId': id,
      'projectName': name,
      'action': 'project_updated',
      'timestamp': DateTime.now().toIso8601String(),
      'memberCount': totalMembers,
      'deliverableCount': deliverableIds.length,
      'sprintCount': sprintIds.length,
      'status': status.name,
      'priority': priority.name,
    };
  }
}
