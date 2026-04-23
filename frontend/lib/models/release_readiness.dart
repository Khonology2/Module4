import 'package:flutter/material.dart';

enum ReadinessStatus {
  green,
  amber,
  red,
}

class ReleaseReadinessCheck {
  final String id;
  final String deliverableId;
  final ReadinessStatus status;
  final List<ReadinessItem> items;
  final String? internalApprover;
  final DateTime? approvedAt;
  final String? approvalComment;
  final DateTime checkedAt;
  final String checkedBy;

  const ReleaseReadinessCheck({
    required this.id,
    required this.deliverableId,
    required this.status,
    required this.items,
    this.internalApprover,
    this.approvedAt,
    this.approvalComment,
    required this.checkedAt,
    required this.checkedBy,
  });

  ReleaseReadinessCheck copyWith({
    String? id,
    String? deliverableId,
    ReadinessStatus? status,
    List<ReadinessItem>? items,
    String? internalApprover,
    DateTime? approvedAt,
    String? approvalComment,
    DateTime? checkedAt,
    String? checkedBy,
  }) {
    return ReleaseReadinessCheck(
      id: id ?? this.id,
      deliverableId: deliverableId ?? this.deliverableId,
      status: status ?? this.status,
      items: items ?? this.items,
      internalApprover: internalApprover ?? this.internalApprover,
      approvedAt: approvedAt ?? this.approvedAt,
      approvalComment: approvalComment ?? this.approvalComment,
      checkedAt: checkedAt ?? this.checkedAt,
      checkedBy: checkedBy ?? this.checkedBy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deliverableId': deliverableId,
      'status': status.name,
      'items': items.map((item) => item.toJson()).toList(),
      'internalApprover': internalApprover,
      'approvedAt': approvedAt?.toIso8601String(),
      'approvalComment': approvalComment,
      'checkedAt': checkedAt.toIso8601String(),
      'checkedBy': checkedBy,
    };
  }

  factory ReleaseReadinessCheck.fromJson(Map<String, dynamic> json) {
    return ReleaseReadinessCheck(
      id: json['id'],
      deliverableId: json['deliverableId'],
      status: ReadinessStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ReadinessStatus.red,
      ),
      items: (json['items'] as List)
          .map((item) => ReadinessItem.fromJson(item))
          .toList(),
      internalApprover: json['internalApprover'],
      approvedAt: json['approvedAt'] != null ? DateTime.parse(json['approvedAt']) : null,
      approvalComment: json['approvalComment'],
      checkedAt: DateTime.parse(json['checkedAt']),
      checkedBy: json['checkedBy'],
    );
  }

  Color get statusColor {
    switch (status) {
      case ReadinessStatus.green:
        return Colors.green;
      case ReadinessStatus.amber:
        return Colors.orange;
      case ReadinessStatus.red:
        return Colors.red;
    }
  }

  String get statusText {
    switch (status) {
      case ReadinessStatus.green:
        return 'Ready for Release';
      case ReadinessStatus.amber:
        return 'Ready with Acknowledged Issues';
      case ReadinessStatus.red:
        return 'Not Ready for Release';
    }
  }

  bool get canProceed => status == ReadinessStatus.green || status == ReadinessStatus.amber;
  bool get isBlocked => status == ReadinessStatus.red && internalApprover == null;
}

class ReadinessItem {
  final String id;
  final String category;
  final String description;
  final bool isRequired;
  final bool isCompleted;
  final String? evidence;
  final String? notes;
  final bool isAcknowledged;

  const ReadinessItem({
    required this.id,
    required this.category,
    required this.description,
    required this.isRequired,
    required this.isCompleted,
    this.evidence,
    this.notes,
    this.isAcknowledged = false,
  });

  ReadinessItem copyWith({
    String? id,
    String? category,
    String? description,
    bool? isRequired,
    bool? isCompleted,
    String? evidence,
    String? notes,
    bool? isAcknowledged,
  }) {
    return ReadinessItem(
      id: id ?? this.id,
      category: category ?? this.category,
      description: description ?? this.description,
      isRequired: isRequired ?? this.isRequired,
      isCompleted: isCompleted ?? this.isCompleted,
      evidence: evidence ?? this.evidence,
      notes: notes ?? this.notes,
      isAcknowledged: isAcknowledged ?? this.isAcknowledged,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'description': description,
      'isRequired': isRequired,
      'isCompleted': isCompleted,
      'evidence': evidence,
      'notes': notes,
      'isAcknowledged': isAcknowledged,
    };
  }

  factory ReadinessItem.fromJson(Map<String, dynamic> json) {
    return ReadinessItem(
      id: json['id'],
      category: json['category'],
      description: json['description'],
      isRequired: json['isRequired'],
      isCompleted: json['isCompleted'],
      evidence: json['evidence'],
      notes: json['notes'],
      isAcknowledged: json['isAcknowledged'] ?? false,
    );
  }

  Color get statusColor {
    if (isCompleted) return Colors.green;
    if (isRequired) return Colors.red;
    return Colors.orange;
  }

  String get statusText {
    if (isCompleted) return 'Completed';
    if (isRequired) return 'Required';
    return 'Optional';
  }
}
