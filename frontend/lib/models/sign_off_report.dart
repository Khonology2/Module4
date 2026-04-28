import 'dart:convert';

import 'package:flutter/material.dart';

enum ReportStatus {
  draft,
  submitted,
  underReview,
  approved,
  changeRequested,
  rejected,
}

class SignOffReport {
  final String id;
  final String deliverableId;
  final String reportTitle;
  final String reportContent;
  final List<String> sprintIds;
  final String? sprintPerformanceData;
  final String? knownLimitations;
  final String? nextSteps;
  final String? preparedBy;
  final String? preparedByName;
  final String? preparedByRole;
  final ReportStatus status;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? submittedAt;
  final String? submittedBy;
  final String? submittedByName;
  final String? submittedByRole;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? reviewedByName;
  final String? reviewedByRole;
  final String? clientComment;
  final String? changeRequestDetails;
  final List<dynamic>? changeRequestHistory;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? approvedByName;
  final String? approvedByRole;

  final String? digitalSignature;

  const SignOffReport({
    required this.id,
    required this.deliverableId,
    required this.reportTitle,
    required this.reportContent,
    required this.sprintIds,
    this.sprintPerformanceData,
    this.knownLimitations,
    this.nextSteps,
    this.preparedBy,
    this.preparedByName,
    this.preparedByRole,
    required this.status,
    required this.createdAt,
    required this.createdBy,
    this.submittedAt,
    this.submittedBy,
    this.submittedByName,
    this.submittedByRole,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewedByName,
    this.reviewedByRole,
    this.clientComment,
    this.changeRequestDetails,
    this.changeRequestHistory,
    this.approvedAt,
    this.approvedBy,
    this.approvedByName,
    this.approvedByRole,
    this.digitalSignature,
  });

  SignOffReport copyWith({
    String? id,
    String? deliverableId,
    String? reportTitle,
    String? reportContent,
    List<String>? sprintIds,
    String? sprintPerformanceData,
    String? knownLimitations,
    String? nextSteps,
    String? preparedBy,
    String? preparedByName,
    String? preparedByRole,
    ReportStatus? status,
    DateTime? createdAt,
    String? createdBy,
    DateTime? submittedAt,
    String? submittedBy,
    String? submittedByName,
    String? submittedByRole,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? reviewedByName,
    String? reviewedByRole,
    String? clientComment,
    String? changeRequestDetails,
    List<dynamic>? changeRequestHistory,
    DateTime? approvedAt,
    String? approvedBy,
    String? approvedByName,
    String? approvedByRole,
    String? digitalSignature,
  }) {
    return SignOffReport(
      id: id ?? this.id,
      deliverableId: deliverableId ?? this.deliverableId,
      reportTitle: reportTitle ?? this.reportTitle,
      reportContent: reportContent ?? this.reportContent,
      sprintIds: sprintIds ?? this.sprintIds,
      sprintPerformanceData: sprintPerformanceData ?? this.sprintPerformanceData,
      knownLimitations: knownLimitations ?? this.knownLimitations,
      nextSteps: nextSteps ?? this.nextSteps,
      preparedBy: preparedBy ?? this.preparedBy,
      preparedByName: preparedByName ?? this.preparedByName,
      preparedByRole: preparedByRole ?? this.preparedByRole,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      submittedAt: submittedAt ?? this.submittedAt,
      submittedBy: submittedBy ?? this.submittedBy,
      submittedByName: submittedByName ?? this.submittedByName,
      submittedByRole: submittedByRole ?? this.submittedByRole,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedByName: reviewedByName ?? this.reviewedByName,
      reviewedByRole: reviewedByRole ?? this.reviewedByRole,
      clientComment: clientComment ?? this.clientComment,
      changeRequestDetails: changeRequestDetails ?? this.changeRequestDetails,
      changeRequestHistory: changeRequestHistory ?? this.changeRequestHistory,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedByName: approvedByName ?? this.approvedByName,
      approvedByRole: approvedByRole ?? this.approvedByRole,
      digitalSignature: digitalSignature ?? this.digitalSignature,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deliverableId': deliverableId,
      'reportTitle': reportTitle,
      'reportContent': reportContent,
      'sprintIds': sprintIds,
      'sprintPerformanceData': sprintPerformanceData,
      'knownLimitations': knownLimitations,
      'nextSteps': nextSteps,
      'preparedBy': preparedBy,
      'preparedByName': preparedByName,
      'preparedByRole': preparedByRole,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'submittedAt': submittedAt?.toIso8601String(),
      'submittedBy': submittedBy,
      'submittedByName': submittedByName,
      'submittedByRole': submittedByRole,
      'reviewedAt': reviewedAt?.toIso8601String(),
      'reviewedBy': reviewedBy,
      'reviewedByName': reviewedByName,
      'reviewedByRole': reviewedByRole,
      'clientComment': clientComment,
      'changeRequestDetails': changeRequestDetails,
      'changeRequestHistory': changeRequestHistory,
      'approvedAt': approvedAt?.toIso8601String(),
      'approvedBy': approvedBy,
      'approvedByName': approvedByName,
      'approvedByRole': approvedByRole,
      'digitalSignature': digitalSignature,
    };
  }

  factory SignOffReport.fromJson(Map<String, dynamic> json) {
    final dynamic contentRaw = json['content'];
    final Map<String, dynamic> content = contentRaw is Map
        ? Map<String, dynamic>.from(contentRaw)
        : (contentRaw is String
            ? (() {
                try {
                  final decoded = jsonDecode(contentRaw);
                  return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
                } catch (_) {
                  return <String, dynamic>{};
                }
              })()
            : <String, dynamic>{});

    final String id = (json['id'] ?? json['report_id'] ?? '').toString();
    final String deliverableId = (json['deliverableId'] ?? json['deliverable_id'] ?? content['deliverableId'] ?? content['deliverable_id'] ?? '').toString();
    final String reportTitle = (json['reportTitle'] ?? json['report_title'] ?? content['reportTitle'] ?? content['title'] ?? '').toString();
    final String reportContent = (json['reportContent'] ?? json['content_text'] ?? content['reportContent'] ?? content['content'] ?? '').toString();

    List<String> sprintIds = [];
    final dynamic sIds = json['sprintIds'] ?? json['sprint_ids'] ?? content['sprintIds'] ?? content['sprints'];
    if (sIds is List) {
      sprintIds = sIds.map((e) => e.toString()).toList();
    }

    final String? sprintPerformanceData = (json['sprintPerformanceData'] ?? content['sprintPerformanceData'])?.toString();
    final String? knownLimitations = (json['knownLimitations'] ?? content['knownLimitations'] ?? content['limitations'])?.toString();
    final String? nextSteps = (json['nextSteps'] ?? content['nextSteps'])?.toString();

    final String? preparedBy = (json['preparedBy'] ?? json['prepared_by'] ?? content['preparedBy'] ?? content['prepared_by'])?.toString();
    final String? preparedByName = (json['preparedByName'] ??
            json['prepared_by_name'] ??
            content['preparedByName'] ??
            content['prepared_by_name'] ??
            json['createdByName'] ??
            json['created_by_name'] ??
            content['createdByName'] ??
            content['created_by_name'])
        ?.toString();
    final String? preparedByRole = (json['preparedByRole'] ??
            json['prepared_by_role'] ??
            content['preparedByRole'] ??
            content['prepared_by_role'])
        ?.toString();

    final String statusStr = (json['status'] ?? json['review_status'] ?? content['status'] ?? '').toString();
    final ReportStatus status = ReportStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => ReportStatus.draft,
    );

    final String createdAtStr = (json['createdAt'] ?? json['created_at'] ?? '').toString();
    final DateTime createdAt = createdAtStr.isNotEmpty ? DateTime.parse(createdAtStr) : DateTime.now();

    final String createdBy = (json['createdByName'] ??
            json['created_by_name'] ??
            json['createdBy'] ??
            json['created_by'] ??
            content['createdByName'] ??
            content['created_by_name'] ??
            content['createdBy'] ??
            '')
        .toString();

    final String submittedAtStr = (json['submittedAt'] ?? json['submitted_at'] ?? '').toString();
    final DateTime? submittedAt = submittedAtStr.isNotEmpty ? DateTime.parse(submittedAtStr) : null;
    final String? submittedBy = (json['submittedBy'] ?? json['submitted_by'] ?? content['submittedBy'])?.toString();
    final String? submittedByName = (json['submittedByName'] ??
            json['submitted_by_name'] ??
            content['submittedByName'] ??
            content['submitted_by_name'])
        ?.toString();
    final String? submittedByRole = (json['submittedByRole'] ??
            json['submitted_by_role'] ??
            content['submittedByRole'] ??
            content['submitted_by_role'])
        ?.toString();

    final String reviewedAtStr = (json['reviewedAt'] ?? json['approved_at'] ?? json['rejected_at'] ?? '').toString();
    final DateTime? reviewedAt = reviewedAtStr.isNotEmpty ? DateTime.parse(reviewedAtStr) : null;
    final String? reviewedBy = (json['reviewedBy'] ?? json['approved_by'] ?? json['rejected_by'] ?? content['reviewedBy'])?.toString();
    final String? reviewedByName = (json['reviewedByName'] ??
            json['reviewed_by_name'] ??
            content['reviewedByName'] ??
            content['reviewed_by_name'])
        ?.toString();
    final String? reviewedByRole = (json['reviewedByRole'] ??
            json['reviewed_by_role'] ??
            content['reviewedByRole'] ??
            content['reviewed_by_role'])
        ?.toString();

    final String? clientComment = (json['clientComment'] ?? content['clientComment'] ?? json['comments'])?.toString();
    final String? changeRequestDetails = (json['changeRequestDetails'] ?? content['changeRequestDetails'])?.toString();
    final List<dynamic>? changeRequestHistory = (json['changeRequestHistory'] ?? content['changeRequestHistory']);

    final String approvedAtStr = (json['approvedAt'] ?? json['approved_at'] ?? '').toString();
    final DateTime? approvedAt = approvedAtStr.isNotEmpty ? DateTime.parse(approvedAtStr) : null;
    final String? approvedBy = (json['approvedBy'] ?? json['approved_by'] ?? content['approvedBy'])?.toString();
    final String? approvedByName = (json['approvedByName'] ??
            json['approved_by_name'] ??
            content['approvedByName'] ??
            content['approved_by_name'])
        ?.toString();
    final String? approvedByRole = (json['approvedByRole'] ??
            json['approved_by_role'] ??
            content['approvedByRole'] ??
            content['approved_by_role'])
        ?.toString();
    final String? digitalSignature = (json['digitalSignature'] ?? json['signature'] ?? content['digitalSignature'])?.toString();

    return SignOffReport(
      id: id,
      deliverableId: deliverableId,
      reportTitle: reportTitle,
      reportContent: reportContent,
      sprintIds: sprintIds,
      sprintPerformanceData: sprintPerformanceData,
      knownLimitations: knownLimitations,
      nextSteps: nextSteps,
      preparedBy: preparedBy,
      preparedByName: preparedByName,
      preparedByRole: preparedByRole,
      status: status,
      createdAt: createdAt,
      createdBy: createdBy,
      submittedAt: submittedAt,
      submittedBy: submittedBy,
      submittedByName: submittedByName,
      submittedByRole: submittedByRole,
      reviewedAt: reviewedAt,
      reviewedBy: reviewedBy,
      reviewedByName: reviewedByName,
      reviewedByRole: reviewedByRole,
      clientComment: clientComment,
      changeRequestDetails: changeRequestDetails,
      changeRequestHistory: changeRequestHistory,
      approvedAt: approvedAt,
      approvedBy: approvedBy,
      approvedByName: approvedByName,
      approvedByRole: approvedByRole,
      digitalSignature: digitalSignature,
    );
  }

  String get statusDisplayName {
    switch (status) {
      case ReportStatus.draft:
        return 'Draft';
      case ReportStatus.submitted:
        return 'Submitted';
      case ReportStatus.underReview:
        return 'Under Review';
      case ReportStatus.approved:
        return 'Approved';
      case ReportStatus.changeRequested:
        return 'Change Requested';
      case ReportStatus.rejected:
        return 'Rejected';
    }
  }

  Color get statusColor {
    switch (status) {
      case ReportStatus.draft:
        return Colors.grey;
      case ReportStatus.submitted:
        return Colors.blue;
      case ReportStatus.underReview:
        return Colors.orange;
      case ReportStatus.approved:
        return Colors.green;
      case ReportStatus.changeRequested:
        return Colors.amber;
      case ReportStatus.rejected:
        return Colors.red;
    }
  }

  bool get isApproved => status == ReportStatus.approved;
  bool get isPendingReview => status == ReportStatus.submitted || status == ReportStatus.underReview;
  bool get needsChanges => status == ReportStatus.changeRequested;
}
