import 'package:flutter/material.dart';

class SprintMetrics {
  final String id;
  final String sprintId;
  final int committedPoints;
  final int completedPoints;
  final int carriedOverPoints;
  final double testPassRate;
  final int defectsOpened;
  final int defectsClosed;
  final int criticalDefects;
  final int highDefects;
  final int mediumDefects;
  final int lowDefects;
  final double codeReviewCompletion;
  final double documentationStatus;
  final String? risks;
  final String? mitigations;
  final String? scopeChanges;
  final int pointsAddedDuringSprint;
  final int pointsRemovedDuringSprint;
  final String? blockers;
  final String? decisions;
  final String? uatNotes;
  final DateTime recordedAt;
  final String recordedBy;

  const SprintMetrics({
    required this.id,
    required this.sprintId,
    required this.committedPoints,
    required this.completedPoints,
    required this.carriedOverPoints,
    required this.testPassRate,
    required this.defectsOpened,
    required this.defectsClosed,
    required this.criticalDefects,
    required this.highDefects,
    required this.mediumDefects,
    required this.lowDefects,
    required this.codeReviewCompletion,
    required this.documentationStatus,
    this.risks,
    this.mitigations,
    this.scopeChanges,
    this.pointsAddedDuringSprint = 0,
    this.pointsRemovedDuringSprint = 0,
    this.blockers,
    this.decisions,
    this.uatNotes,
    required this.recordedAt,
    required this.recordedBy,
  });

  SprintMetrics copyWith({
    String? id,
    String? sprintId,
    int? committedPoints,
    int? completedPoints,
    int? carriedOverPoints,
    double? testPassRate,
    int? defectsOpened,
    int? defectsClosed,
    int? criticalDefects,
    int? highDefects,
    int? mediumDefects,
    int? lowDefects,
    double? codeReviewCompletion,
    double? documentationStatus,
    String? risks,
    String? mitigations,
    String? scopeChanges,
    int? pointsAddedDuringSprint,
    int? pointsRemovedDuringSprint,
    String? blockers,
    String? decisions,
    String? uatNotes,
    DateTime? recordedAt,
    String? recordedBy,
  }) {
    return SprintMetrics(
      id: id ?? this.id,
      sprintId: sprintId ?? this.sprintId,
      committedPoints: committedPoints ?? this.committedPoints,
      completedPoints: completedPoints ?? this.completedPoints,
      carriedOverPoints: carriedOverPoints ?? this.carriedOverPoints,
      testPassRate: testPassRate ?? this.testPassRate,
      defectsOpened: defectsOpened ?? this.defectsOpened,
      defectsClosed: defectsClosed ?? this.defectsClosed,
      criticalDefects: criticalDefects ?? this.criticalDefects,
      highDefects: highDefects ?? this.highDefects,
      mediumDefects: mediumDefects ?? this.mediumDefects,
      lowDefects: lowDefects ?? this.lowDefects,
      codeReviewCompletion: codeReviewCompletion ?? this.codeReviewCompletion,
      documentationStatus: documentationStatus ?? this.documentationStatus,
      risks: risks ?? this.risks,
      mitigations: mitigations ?? this.mitigations,
      scopeChanges: scopeChanges ?? this.scopeChanges,
      pointsAddedDuringSprint: pointsAddedDuringSprint ?? this.pointsAddedDuringSprint,
      pointsRemovedDuringSprint: pointsRemovedDuringSprint ?? this.pointsRemovedDuringSprint,
      blockers: blockers ?? this.blockers,
      decisions: decisions ?? this.decisions,
      uatNotes: uatNotes ?? this.uatNotes,
      recordedAt: recordedAt ?? this.recordedAt,
      recordedBy: recordedBy ?? this.recordedBy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sprintId': sprintId,
      'committedPoints': committedPoints,
      'completedPoints': completedPoints,
      'carriedOverPoints': carriedOverPoints,
      'testPassRate': testPassRate,
      'defectsOpened': defectsOpened,
      'defectsClosed': defectsClosed,
      'criticalDefects': criticalDefects,
      'highDefects': highDefects,
      'mediumDefects': mediumDefects,
      'lowDefects': lowDefects,
      'codeReviewCompletion': codeReviewCompletion,
      'documentationStatus': documentationStatus,
      'risks': risks,
      'mitigations': mitigations,
      'scopeChanges': scopeChanges,
      'pointsAddedDuringSprint': pointsAddedDuringSprint,
      'pointsRemovedDuringSprint': pointsRemovedDuringSprint,
      'blockers': blockers,
      'decisions': decisions,
      'uatNotes': uatNotes,
      'recordedAt': recordedAt.toIso8601String(),
      'recordedBy': recordedBy,
    };
  }

  factory SprintMetrics.fromJson(Map<String, dynamic> json) {
    return SprintMetrics(
      id: json['id'],
      sprintId: json['sprintId'],
      committedPoints: json['committedPoints'] is int ? json['committedPoints'] : int.tryParse(json['committedPoints']?.toString() ?? '') ?? 0,
      completedPoints: json['completedPoints'] is int ? json['completedPoints'] : int.tryParse(json['completedPoints']?.toString() ?? '') ?? 0,
      carriedOverPoints: json['carriedOverPoints'] is int ? json['carriedOverPoints'] : int.tryParse(json['carriedOverPoints']?.toString() ?? '') ?? 0,
      testPassRate: json['testPassRate'] is double ? json['testPassRate'] : double.tryParse(json['testPassRate']?.toString() ?? '') ?? 0.0,
      defectsOpened: json['defectsOpened'] is int ? json['defectsOpened'] : int.tryParse(json['defectsOpened']?.toString() ?? '') ?? 0,
      defectsClosed: json['defectsClosed'] is int ? json['defectsClosed'] : int.tryParse(json['defectsClosed']?.toString() ?? '') ?? 0,
      criticalDefects: json['criticalDefects'] is int ? json['criticalDefects'] : int.tryParse(json['criticalDefects']?.toString() ?? '') ?? 0,
      highDefects: json['highDefects'] is int ? json['highDefects'] : int.tryParse(json['highDefects']?.toString() ?? '') ?? 0,
      mediumDefects: json['mediumDefects'] is int ? json['mediumDefects'] : int.tryParse(json['mediumDefects']?.toString() ?? '') ?? 0,
      lowDefects: json['lowDefects'] is int ? json['lowDefects'] : int.tryParse(json['lowDefects']?.toString() ?? '') ?? 0,
      codeReviewCompletion: json['codeReviewCompletion'] is double ? json['codeReviewCompletion'] : double.tryParse(json['codeReviewCompletion']?.toString() ?? '') ?? 0.0,
      documentationStatus: json['documentationStatus'] is double ? json['documentationStatus'] : double.tryParse(json['documentationStatus']?.toString() ?? '') ?? 0.0,
      risks: json['risks'],
      mitigations: json['mitigations'],
      scopeChanges: json['scopeChanges'],
      pointsAddedDuringSprint: json['pointsAddedDuringSprint'] ?? 0,
      pointsRemovedDuringSprint: json['pointsRemovedDuringSprint'] ?? 0,
      blockers: json['blockers'],
      decisions: json['decisions'],
      uatNotes: json['uatNotes'],
      recordedAt: DateTime.parse(json['recordedAt']),
      recordedBy: json['recordedBy'],
    );
  }

  // Calculated properties
  double get velocity => completedPoints.toDouble();
  double get completionRate => committedPoints > 0 ? (completedPoints / committedPoints) * 100 : 0.0;
  int get totalDefects => defectsOpened;
  int get netDefects => defectsOpened - defectsClosed;
  double get defectResolutionRate => defectsOpened > 0 ? (defectsClosed / defectsOpened) * 100 : 0.0;
  
  // Scope change properties
  int get netScopeChange => pointsAddedDuringSprint - pointsRemovedDuringSprint;
  bool get hasScopeChange => pointsAddedDuringSprint > 0 || pointsRemovedDuringSprint > 0;
  String get scopeChangeIndicator {
    if (netScopeChange > 0) return '+$netScopeChange pts';
    if (netScopeChange < 0) return '$netScopeChange pts';
    return 'No change';
  }
  Color get scopeChangeColor {
    if (netScopeChange > 0) return Colors.orange; // Scope creep warning
    if (netScopeChange < 0) return Colors.blue; // Scope reduced
    return Colors.green; // Stable
  }
  
  Color get qualityStatusColor {
    if (testPassRate >= 95 && netDefects <= 2) return Colors.green;
    if (testPassRate >= 90 && netDefects <= 5) return Colors.orange;
    return Colors.red;
  }

  String get qualityStatusText {
    if (testPassRate >= 95 && netDefects <= 2) return 'Excellent';
    if (testPassRate >= 90 && netDefects <= 5) return 'Good';
    return 'Needs Attention';
  }
}
