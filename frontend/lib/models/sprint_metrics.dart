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
      'sprint_id': sprintId,
      'committed_points': committedPoints,
      'completed_points': completedPoints,
      'carried_over_points': carriedOverPoints,
      'test_pass_rate': testPassRate,
      'defects_opened': defectsOpened,
      'defects_closed': defectsClosed,
      'critical_defects': criticalDefects,
      'high_defects': highDefects,
      'medium_defects': mediumDefects,
      'low_defects': lowDefects,
      'code_review_completion': codeReviewCompletion,
      'documentation_status': documentationStatus,
      'points_added': pointsAddedDuringSprint,
      'points_removed': pointsRemovedDuringSprint,
      'uat_notes': uatNotes,
      'recorded_at': recordedAt.toIso8601String(),
      'recorded_by': recordedBy,
    };
  }

  factory SprintMetrics.fromJson(Map<String, dynamic> json) {
    dynamic pick(List<String> keys) {
      for (final k in keys) {
        if (json.containsKey(k) && json[k] != null) return json[k];
      }
      return null;
    }

    String pickString(List<String> keys, {String fallback = ''}) {
      final v = pick(keys);
      if (v == null) return fallback;
      return v.toString();
    }

    int pickInt(List<String> keys, {int fallback = 0}) {
      final v = pick(keys);
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    double pickDouble(List<String> keys, {double fallback = 0.0}) {
      final v = pick(keys);
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? fallback;
    }

    DateTime pickDateTime(List<String> keys) {
      final v = pick(keys);
      final s = v?.toString();
      if (s == null || s.isEmpty) return DateTime.now();
      return DateTime.tryParse(s) ?? DateTime.now();
    }

    final sprintId = pickString(['sprintId', 'sprint_id'], fallback: '');
    final id = pickString(['id', 'metricId', 'metric_id'], fallback: DateTime.now().millisecondsSinceEpoch.toString());

    return SprintMetrics(
      id: id,
      sprintId: sprintId,
      committedPoints: pickInt(['committedPoints', 'committed_points']),
      completedPoints: pickInt(['completedPoints', 'completed_points']),
      carriedOverPoints: pickInt(['carriedOverPoints', 'carried_over_points']),
      testPassRate: pickDouble(['testPassRate', 'test_pass_rate']),
      defectsOpened: pickInt(['defectsOpened', 'defects_opened']),
      defectsClosed: pickInt(['defectsClosed', 'defects_closed']),
      criticalDefects: pickInt(['criticalDefects', 'critical_defects']),
      highDefects: pickInt(['highDefects', 'high_defects']),
      mediumDefects: pickInt(['mediumDefects', 'medium_defects']),
      lowDefects: pickInt(['lowDefects', 'low_defects']),
      codeReviewCompletion: pickDouble(['codeReviewCompletion', 'code_review_completion']),
      documentationStatus: pickDouble(['documentationStatus', 'documentation_status']),
      risks: pick(['risks'])?.toString(),
      mitigations: pick(['mitigations'])?.toString(),
      scopeChanges: pick(['scopeChanges', 'scope_changes'])?.toString(),
      pointsAddedDuringSprint: pickInt(['pointsAddedDuringSprint', 'points_added', 'points_added_during_sprint']),
      pointsRemovedDuringSprint: pickInt(['pointsRemovedDuringSprint', 'points_removed', 'points_removed_during_sprint']),
      blockers: pick(['blockers'])?.toString(),
      decisions: pick(['decisions'])?.toString(),
      uatNotes: pick(['uatNotes', 'uat_notes'])?.toString(),
      recordedAt: pickDateTime(['recordedAt', 'recorded_at', 'created_at', 'updated_at']),
      recordedBy: pickString(['recordedBy', 'recorded_by', 'created_by'], fallback: ''),
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
