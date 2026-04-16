import 'dart:convert';
import 'package:flutter/material.dart';
import 'dod_item.dart';
import 'audit_log_entry.dart';
import 'deliverable_artifact.dart';

export 'dod_item.dart';
export 'audit_log_entry.dart';
export 'deliverable_artifact.dart';

enum DeliverableStatus {
  draft,
  inProgress,
  inReview,
  signedOff,
  submitted, // Legacy: treat as inReview
  approved, // Legacy: treat as signedOff
  changeRequested,
  rejected,
}

extension DeliverableStatusX on DeliverableStatus {
  String get displayName {
    switch (this) {
      case DeliverableStatus.draft:
        return 'Draft';
      case DeliverableStatus.inProgress:
        return 'In Progress';
      case DeliverableStatus.inReview:
      case DeliverableStatus.submitted:
        return 'In Review';
      case DeliverableStatus.signedOff:
      case DeliverableStatus.approved:
        return 'Signed Off';
      case DeliverableStatus.changeRequested:
        return 'Change Requested';
      case DeliverableStatus.rejected:
        return 'Rejected';
    }
  }

  Color get color {
    switch (this) {
      case DeliverableStatus.draft:
        return Colors.grey;
      case DeliverableStatus.inProgress:
        return Colors.blue;
      case DeliverableStatus.inReview:
      case DeliverableStatus.submitted:
        return Colors.orange;
      case DeliverableStatus.signedOff:
      case DeliverableStatus.approved:
        return Colors.green;
      case DeliverableStatus.changeRequested:
        return Colors.amber;
      case DeliverableStatus.rejected:
        return Colors.red;
    }
  }
}

class Deliverable {
  final String id;
  final String title;
  final String description;
  final String priority;
  final DeliverableStatus status;
  final DateTime createdAt;
  final DateTime dueDate;
  final List<String> sprintIds;
  final List<DoDItem> definitionOfDone;
  final List<String> evidenceLinks;
  final String? clientComment;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? submittedBy;
  final String? submittedByName;
  final DateTime? submittedAt;
  final String? assignedTo;
  final String? assignedToName;
  final String? createdBy;
  final String? createdByName;
  final String? ownerId;
  final String? ownerName;
  final String? ownerRole;
  final String? projectId;
  final String? projectName;
  final List<AuditLogEntry> auditLogs;
  final List<DeliverableArtifact> artifacts;

  const Deliverable({
    required this.id,
    required this.title,
    required this.description,
    this.priority = 'medium',
    required this.status,
    required this.createdAt,
    required this.dueDate,
    required this.sprintIds,
    required this.definitionOfDone,
    this.evidenceLinks = const [],
    this.clientComment,
    this.approvedAt,
    this.approvedBy,
    this.submittedBy,
    this.submittedByName,
    this.submittedAt,
    this.assignedTo,
    this.assignedToName,
    this.createdBy,
    this.createdByName,
    this.ownerId,
    this.ownerName,
    this.ownerRole,
    this.projectId,
    this.projectName,
    this.auditLogs = const [],
    this.artifacts = const [],
  });

  Deliverable copyWith({
    String? id,
    String? title,
    String? description,
    String? priority,
    DeliverableStatus? status,
    DateTime? createdAt,
    DateTime? dueDate,
    List<String>? sprintIds,
    List<DoDItem>? definitionOfDone,
    List<String>? evidenceLinks,
    String? clientComment,
    DateTime? approvedAt,
    String? approvedBy,
    String? submittedBy,
    String? submittedByName,
    DateTime? submittedAt,
    String? assignedTo,
    String? assignedToName,
    String? createdBy,
    String? createdByName,
    String? ownerId,
    String? ownerName,
    String? ownerRole,
    String? projectId,
    String? projectName,
    List<AuditLogEntry>? auditLogs,
  }) {
    return Deliverable(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      sprintIds: sprintIds ?? this.sprintIds,
      definitionOfDone: definitionOfDone ?? this.definitionOfDone,
      evidenceLinks: evidenceLinks ?? this.evidenceLinks,
      clientComment: clientComment ?? this.clientComment,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      submittedBy: submittedBy ?? this.submittedBy,
      submittedByName: submittedByName ?? this.submittedByName,
      submittedAt: submittedAt ?? this.submittedAt,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      ownerRole: ownerRole ?? this.ownerRole,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      auditLogs: auditLogs ?? this.auditLogs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'priority': priority,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'sprintIds': sprintIds,
      'definitionOfDone': definitionOfDone.map((e) => e.toJson()).toList(),
      'evidenceLinks': evidenceLinks,
      'clientComment': clientComment,
      'approvedAt': approvedAt?.toIso8601String(),
      'approvedBy': approvedBy,
      'submittedBy': submittedBy,
      'submittedByName': submittedByName,
      'submittedAt': submittedAt?.toIso8601String(),
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerRole': ownerRole,
      'projectId': projectId,
      'projectName': projectName,
      'artifacts': artifacts.map((e) => e.toJson()).toList(),
      // We don't necessarily need to send audit logs back to server, but good for completeness
      // 'auditLogs': auditLogs.map((e) => e.toJson()).toList(), 
    };
  }

  factory Deliverable.fromJson(Map<String, dynamic> json) {
    // Helper to parse status
    DeliverableStatus parseStatus(String? statusStr) {
      if (statusStr == null) return DeliverableStatus.draft;
      
      final lower = statusStr.toLowerCase();
      // Explicit mappings for backend values
      if (lower == 'review' || lower == 'in_review') return DeliverableStatus.inReview;
      if (lower == 'completed' || lower == 'signed_off') return DeliverableStatus.signedOff;
      if (lower == 'in_progress' || lower == 'active') return DeliverableStatus.inProgress;
      
      // Handle snake_case or camelCase
      final normalized = lower.replaceAll('_', '');
      for (var val in DeliverableStatus.values) {
        if (val.name.toLowerCase() == normalized) return val;
      }
      return DeliverableStatus.draft;
    }

    // Helper to parse DoD items
    List<DoDItem> parseDoD(dynamic dodValue) {
      if (dodValue == null) return [];
      if (dodValue is List) {
        return dodValue.map((item) {
          if (item is Map<String, dynamic>) return DoDItem.fromJson(item);
          if (item is DoDItem) return item;
          return DoDItem(text: item.toString());
        }).toList();
      } else if (dodValue is String) {
        try {
          final decoded = jsonDecode(dodValue);
          if (decoded is List) {
            return decoded.map((item) {
              if (item is Map<String, dynamic>) return DoDItem.fromJson(item);
              return DoDItem(text: item.toString());
            }).toList();
          }
        } catch (_) {
          // Not JSON, split by newline
          if (dodValue.trim().isNotEmpty) {
             return dodValue.split('\n')
               .map((s) => s.trim())
               .where((s) => s.isNotEmpty)
               .map((s) => DoDItem(text: s))
               .toList();
          }
        }
      }
      return [];
    }

    // Handle sprintIds which might come as 'sprintIds' (List) or 'sprint_id' (String)
    List<String> parseSprintIds(Map<String, dynamic> json) {
      final ids = <String>{};

      void add(dynamic v) {
        final s = v?.toString();
        if (s != null && s.trim().isNotEmpty) ids.add(s.trim());
      }

      void addFromList(dynamic v) {
        if (v is List) {
          for (final item in v) {
            add(item);
          }
        }
      }

      addFromList(json['sprintIds']);
      addFromList(json['sprint_ids']);

      add(json['sprint_id']);
      add(json['sprintId']);

      final contributing = json['contributing_sprints'] ?? json['contributingSprints'] ?? json['sprints'];
      if (contributing is List) {
        for (final item in contributing) {
          if (item is Map) {
            add(item['id'] ?? item['sprint_id'] ?? item['sprintId']);
          } else {
            add(item);
          }
        }
      }

      return ids.toList();
    }
    
    // Handle camelCase and snake_case keys
    final id = json['id']?.toString() ?? json['uuid']?.toString() ?? '';
    final title = json['title']?.toString() ?? json['name']?.toString() ?? '';
    final description = json['description']?.toString() ?? '';
    final priority = json['priority']?.toString() ?? 'medium';
    final status = parseStatus(json['status']?.toString() ?? json['review_status']?.toString());
    
    final createdStr = json['createdAt']?.toString() ?? json['created_at']?.toString();
    final createdAt = createdStr != null ? DateTime.parse(createdStr) : DateTime.now();
    
    final dueStr = json['dueDate']?.toString() ?? json['due_date']?.toString() ?? json['deadline']?.toString();
    final dueDate = dueStr != null ? DateTime.parse(dueStr) : DateTime.now().add(const Duration(days: 7));
    
    final sprintIds = parseSprintIds(json);
    
    final dodValue = json['definitionOfDone'] ?? json['definition_of_done'];
    final definitionOfDone = parseDoD(dodValue);
    
    final evidenceValue = json['evidenceLinks'] ?? json['evidence_links'];
    final evidenceLinks = evidenceValue != null ? List<String>.from(evidenceValue) : <String>[];
    
    // Handle nested owner object
    String? ownerId = json['ownerId']?.toString() ?? json['owner_id']?.toString();
    String? ownerName = json['ownerName']?.toString() ?? json['owner_name']?.toString();
    String? ownerRole = json['ownerRole']?.toString() ?? json['owner_role']?.toString();
    
    if (json['owner'] != null && json['owner'] is Map) {
      final ownerMap = json['owner'] as Map;
      ownerId ??= ownerMap['id']?.toString();
      ownerRole ??= ownerMap['role']?.toString();
      if (ownerName == null) {
        final first = ownerMap['first_name']?.toString() ?? ownerMap['firstName']?.toString() ?? '';
        final last = ownerMap['last_name']?.toString() ?? ownerMap['lastName']?.toString() ?? '';
        final email = ownerMap['email']?.toString() ?? '';
        if (first.isNotEmpty || last.isNotEmpty) {
          ownerName = '$first $last'.trim();
        } else if (email.isNotEmpty) {
          ownerName = email;
        }
      }
    }

    // Parse Audit Logs
    final auditLogsJson = json['auditLogs'] ?? json['audit_logs'];
    List<AuditLogEntry> auditLogs = [];
    if (auditLogsJson != null && auditLogsJson is List) {
      auditLogs = auditLogsJson
          .map((e) {
            try {
              return AuditLogEntry.fromJson(e as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<AuditLogEntry>()
          .toList();
      // Sort by newest first
      auditLogs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    // Parse Artifacts
    final artifactsJson = json['artifacts'];
    List<DeliverableArtifact> artifacts = [];
    if (artifactsJson != null && artifactsJson is List) {
      artifacts = artifactsJson
          .map((e) => DeliverableArtifact.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return Deliverable(
      id: id,
      title: title,
      description: description,
      priority: priority,
      status: status,
      createdAt: createdAt,
      dueDate: dueDate,
      sprintIds: sprintIds,
      definitionOfDone: definitionOfDone,
      evidenceLinks: evidenceLinks,
      clientComment: json['clientComment']?.toString() ?? json['client_comment']?.toString(),
      approvedAt: json['approvedAt'] != null
          ? DateTime.parse(json['approvedAt'].toString())
          : (json['approved_at'] != null ? DateTime.parse(json['approved_at'].toString()) : null),
      approvedBy: json['approvedBy']?.toString() ?? json['approved_by']?.toString(),
      submittedBy: json['submittedBy']?.toString() ?? json['submitted_by']?.toString(),
      submittedByName: json['submittedByName']?.toString() ?? json['submitted_by_name']?.toString(),
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'].toString())
          : (json['submitted_at'] != null ? DateTime.parse(json['submitted_at'].toString()) : null),
      assignedTo: json['assignedTo']?.toString() ?? json['assigned_to']?.toString(),
      assignedToName: json['assignedToName']?.toString() ?? json['assigned_to_name']?.toString(),
      createdBy: json['createdBy']?.toString() ?? json['created_by']?.toString(),
      createdByName: json['createdByName']?.toString() ?? json['created_by_name']?.toString(),
      ownerId: ownerId,
      ownerName: ownerName,
      ownerRole: ownerRole,
      projectId: json['projectId']?.toString() ?? json['project_id']?.toString(),
      projectName: json['projectName']?.toString() ?? json['project_name']?.toString(),
      auditLogs: auditLogs,
      artifacts: artifacts,
    );
  }

  String get statusDisplayName => status.displayName;

  Color get statusColor => status.color;

  bool get isOverdue {
    return DateTime.now().isAfter(dueDate) && 
           status != DeliverableStatus.approved && 
           status != DeliverableStatus.signedOff;
  }

  int get daysUntilDue {
    return dueDate.difference(DateTime.now()).inDays;
  }
}

class DeliverableCreate {
  final String title;
  final String description;
  final DateTime dueDate;
  final List<String> definitionOfDone;
  final List<String> evidenceLinks;
  final List<String> sprintIds;

  const DeliverableCreate({
    required this.title,
    required this.description,
    required this.dueDate,
    this.definitionOfDone = const [],
    this.evidenceLinks = const [],
    this.sprintIds = const [],
  });
}
