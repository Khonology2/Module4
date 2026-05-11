/// Epic model - represents a feature or epic that spans multiple sprints
class Epic {
  final String id;
  final String title;
  final String? description;
  final String status; // draft, in_progress, completed, cancelled
  final String? projectId;
  final List<String> sprintIds;
  final List<String> deliverableIds;
  final DateTime? startDate;
  final DateTime? targetDate;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Epic({
    required this.id,
    required this.title,
    this.description,
    this.status = 'draft',
    this.projectId,
    this.sprintIds = const [],
    this.deliverableIds = const [],
    this.startDate,
    this.targetDate,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory Epic.fromJson(Map<String, dynamic> json) {
    return Epic(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      status: json['status']?.toString() ?? 'draft',
      projectId: json['project_id']?.toString() ?? json['projectId']?.toString(),
      sprintIds: _parseStringList(json['sprint_ids'] ?? json['sprintIds']),
      deliverableIds: _parseStringList(json['deliverable_ids'] ?? json['deliverableIds']),
      startDate: json['start_date'] != null 
          ? DateTime.tryParse(json['start_date'].toString())
          : json['startDate'] != null 
              ? DateTime.tryParse(json['startDate'].toString())
              : null,
      targetDate: json['target_date'] != null 
          ? DateTime.tryParse(json['target_date'].toString())
          : json['targetDate'] != null 
              ? DateTime.tryParse(json['targetDate'].toString())
              : null,
      createdBy: json['created_by']?.toString() ?? json['createdBy']?.toString(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'].toString())
          : json['createdAt'] != null 
              ? DateTime.parse(json['createdAt'].toString())
              : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.tryParse(json['updated_at'].toString())
          : json['updatedAt'] != null 
              ? DateTime.tryParse(json['updatedAt'].toString())
              : null,
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String) {
      // Handle JSON string array
      if (value.startsWith('[')) {
        try {
          final parsed = value.substring(1, value.length - 1).split(',');
          return parsed.map((e) => e.trim().replaceAll('"', '')).where((e) => e.isNotEmpty).toList();
        } catch (_) {
          return [];
        }
      }
      return [value];
    }
    return [];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'project_id': projectId,
      'sprint_ids': sprintIds,
      'deliverable_ids': deliverableIds,
      'start_date': startDate?.toIso8601String(),
      'target_date': targetDate?.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Epic copyWith({
    String? id,
    String? title,
    String? description,
    String? status,
    String? projectId,
    List<String>? sprintIds,
    List<String>? deliverableIds,
    DateTime? startDate,
    DateTime? targetDate,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Epic(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      projectId: projectId ?? this.projectId,
      sprintIds: sprintIds ?? this.sprintIds,
      deliverableIds: deliverableIds ?? this.deliverableIds,
      startDate: startDate ?? this.startDate,
      targetDate: targetDate ?? this.targetDate,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get statusDisplayName {
    switch (status.toLowerCase()) {
      case 'draft':
        return 'Draft';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  int get totalSprints => sprintIds.length;
  int get totalDeliverables => deliverableIds.length;
}
