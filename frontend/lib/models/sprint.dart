import 'package:flutter/material.dart';

class Sprint {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final int committedPoints;
  final int completedPoints;
  final int velocity;
  final double testPassRate;
  final int codeCoverage;
  final int escapedDefects;
  final int defectsOpened;
  final int defectsClosed;
  final Map<String, dynamic>? defectSeverityMix;
  final int codeReviewCompletion;
  final String? documentationStatus;
  final String? uatNotes;
  final int uatPassRate;
  final int risksIdentified;
  final String? risks;
  final int risksMitigated;
  final String? blockers;
  final String? decisions;
  final int defectCount;
  final int carriedOverPoints;
  final List<String> scopeChanges;
  final String? notes;
  final bool isActive;

  const Sprint({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.committedPoints,
    required this.completedPoints,
    required this.velocity,
    required this.testPassRate,
    this.codeCoverage = 0,
    this.escapedDefects = 0,
    this.defectsOpened = 0,
    this.defectsClosed = 0,
    this.defectSeverityMix,
    this.codeReviewCompletion = 0,
    this.documentationStatus,
    this.uatNotes,
    this.uatPassRate = 0,
    this.risksIdentified = 0,
    this.risks,
    this.risksMitigated = 0,
    this.blockers,
    this.decisions,
    required this.defectCount,
    this.carriedOverPoints = 0,
    this.scopeChanges = const [],
    this.notes,
    this.isActive = false,
  });

  Sprint copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    int? committedPoints,
    int? completedPoints,
    int? velocity,
    double? testPassRate,
    int? codeCoverage,
    int? escapedDefects,
    int? defectsOpened,
    int? defectsClosed,
    Map<String, dynamic>? defectSeverityMix,
    int? codeReviewCompletion,
    String? documentationStatus,
    String? uatNotes,
    int? uatPassRate,
    int? risksIdentified,
    String? risks,
    int? risksMitigated,
    String? blockers,
    String? decisions,
    int? defectCount,
    int? carriedOverPoints,
    List<String>? scopeChanges,
    String? notes,
    bool? isActive,
  }) {
    return Sprint(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      committedPoints: committedPoints ?? this.committedPoints,
      completedPoints: completedPoints ?? this.completedPoints,
      velocity: velocity ?? this.velocity,
      testPassRate: testPassRate ?? this.testPassRate,
      codeCoverage: codeCoverage ?? this.codeCoverage,
      escapedDefects: escapedDefects ?? this.escapedDefects,
      defectsOpened: defectsOpened ?? this.defectsOpened,
      defectsClosed: defectsClosed ?? this.defectsClosed,
      defectSeverityMix: defectSeverityMix ?? this.defectSeverityMix,
      codeReviewCompletion: codeReviewCompletion ?? this.codeReviewCompletion,
      documentationStatus: documentationStatus ?? this.documentationStatus,
      uatNotes: uatNotes ?? this.uatNotes,
      uatPassRate: uatPassRate ?? this.uatPassRate,
      risksIdentified: risksIdentified ?? this.risksIdentified,
      risks: risks ?? this.risks,
      risksMitigated: risksMitigated ?? this.risksMitigated,
      blockers: blockers ?? this.blockers,
      decisions: decisions ?? this.decisions,
      defectCount: defectCount ?? this.defectCount,
      carriedOverPoints: carriedOverPoints ?? this.carriedOverPoints,
      scopeChanges: scopeChanges ?? this.scopeChanges,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'committedPoints': committedPoints,
      'completedPoints': completedPoints,
      'velocity': velocity,
      'testPassRate': testPassRate,
      'codeCoverage': codeCoverage,
      'escapedDefects': escapedDefects,
      'defectsOpened': defectsOpened,
      'defectsClosed': defectsClosed,
      'defectSeverityMix': defectSeverityMix,
      'codeReviewCompletion': codeReviewCompletion,
      'documentationStatus': documentationStatus,
      'uatNotes': uatNotes,
      'uatPassRate': uatPassRate,
      'risksIdentified': risksIdentified,
      'risks': risks,
      'risksMitigated': risksMitigated,
      'blockers': blockers,
      'decisions': decisions,
      'defectCount': defectCount,
      'carriedOverPoints': carriedOverPoints,
      'scopeChanges': scopeChanges,
      'notes': notes,
      'isActive': isActive,
    };
  }

  factory Sprint.fromJson(Map<String, dynamic> json) {
    return Sprint(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? json['start_date']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['endDate']?.toString() ?? json['end_date']?.toString() ?? '') ?? DateTime.now(),
      committedPoints: json['committedPoints'] is int ? json['committedPoints'] : int.tryParse(json['committedPoints']?.toString() ?? '') ?? 0,
      completedPoints: json['completedPoints'] is int ? json['completedPoints'] : int.tryParse(json['completedPoints']?.toString() ?? '') ?? 0,
      velocity: json['velocity'] is int ? json['velocity'] : int.tryParse(json['velocity']?.toString() ?? '') ?? 0,
      testPassRate: json['testPassRate'] is double ? json['testPassRate'] : double.tryParse(json['testPassRate']?.toString() ?? '') ?? 0.0,
      codeCoverage: json['codeCoverage'] is int ? json['codeCoverage'] : int.tryParse(json['codeCoverage']?.toString() ?? '') ?? 0,
      escapedDefects: json['escapedDefects'] is int ? json['escapedDefects'] : int.tryParse(json['escapedDefects']?.toString() ?? '') ?? 0,
      defectsOpened: json['defectsOpened'] is int ? json['defectsOpened'] : int.tryParse(json['defectsOpened']?.toString() ?? '') ?? 0,
      defectsClosed: json['defectsClosed'] is int ? json['defectsClosed'] : int.tryParse(json['defectsClosed']?.toString() ?? '') ?? 0,
      defectSeverityMix: json['defectSeverityMix'] is Map ? Map<String, dynamic>.from(json['defectSeverityMix']) : null,
      codeReviewCompletion: json['codeReviewCompletion'] is int ? json['codeReviewCompletion'] : int.tryParse(json['codeReviewCompletion']?.toString() ?? '') ?? 0,
      documentationStatus: json['documentationStatus'],
      uatNotes: json['uatNotes'],
      uatPassRate: json['uatPassRate'] is int ? json['uatPassRate'] : int.tryParse(json['uatPassRate']?.toString() ?? '') ?? 0,
      risksIdentified: json['risksIdentified'] is int ? json['risksIdentified'] : int.tryParse(json['risksIdentified']?.toString() ?? '') ?? 0,
      risks: json['risks'],
      risksMitigated: json['risksMitigated'] is int ? json['risksMitigated'] : int.tryParse(json['risksMitigated']?.toString() ?? '') ?? 0,
      blockers: json['blockers'],
      decisions: json['decisions'],
      defectCount: json['defectCount'] is int ? json['defectCount'] : int.tryParse(json['defectCount']?.toString() ?? '') ?? 0,
      carriedOverPoints: json['carriedOverPoints'] is int ? json['carriedOverPoints'] : int.tryParse(json['carriedOverPoints']?.toString() ?? '') ?? 0,
      scopeChanges: List<String>.from(json['scopeChanges'] ?? []),
      notes: json['notes'],
      isActive: json['isActive'] ?? false,
    );
  }

  double get completionRate {
    if (committedPoints == 0) return 0.0;
    return (completedPoints / committedPoints) * 100;
  }

  int get remainingPoints {
    return committedPoints - completedPoints;
  }

  bool get isCompleted {
    return DateTime.now().isAfter(endDate);
  }

  bool get isInProgress {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  int get daysRemaining {
    if (isCompleted) return 0;
    return endDate.difference(DateTime.now()).inDays;
  }

  Color get statusColor {
    if (isCompleted) {
      return completionRate >= 100 ? Colors.green : Colors.orange;
    } else if (isInProgress) {
      return Colors.blue;
    } else {
      return Colors.grey;
    }
  }

  String get statusText {
    if (isCompleted) {
      return completionRate >= 100 ? 'Completed' : 'Overdue';
    } else if (isInProgress) {
      return 'In Progress';
    } else {
      return 'Not Started';
    }
  }
}

class SprintCreate {
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final int committedPoints;
  final int completedPoints;
  final int velocity;
  final double testPassRate;
  final int codeCoverage;
  final int escapedDefects;
  final int defectsOpened;
  final int defectsClosed;
  final Map<String, dynamic>? defectSeverityMix;
  final int codeReviewCompletion;
  final String? documentationStatus;
  final String? uatNotes;
  final int uatPassRate;
  final int risksIdentified;
  final String? risks;
  final int risksMitigated;
  final String? blockers;
  final String? decisions;
  final int defectCount;
  final int carriedOverPoints;
  final List<String> scopeChanges;
  final String? notes;

  const SprintCreate({
    required this.name,
    required this.startDate,
    required this.endDate,
    this.committedPoints = 0,
    this.completedPoints = 0,
    this.velocity = 0,
    this.testPassRate = 0,
    this.codeCoverage = 0,
    this.escapedDefects = 0,
    this.defectsOpened = 0,
    this.defectsClosed = 0,
    this.defectSeverityMix,
    this.codeReviewCompletion = 0,
    this.documentationStatus,
    this.uatNotes,
    this.uatPassRate = 0,
    this.risksIdentified = 0,
    this.risks,
    this.risksMitigated = 0,
    this.blockers,
    this.decisions,
    this.defectCount = 0,
    this.carriedOverPoints = 0,
    this.scopeChanges = const [],
    this.notes,
  });
}
