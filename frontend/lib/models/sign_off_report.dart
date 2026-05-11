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
  final Map<String, dynamic>? sprintReportData;
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
  final int currentVersion;
  final List<dynamic> versionHistory;
  final bool isArchived;
  final DateTime? archivedAt;
  final DateTime? sealedAt;

  const SignOffReport({
    required this.id,
    required this.deliverableId,
    required this.reportTitle,
    required this.reportContent,
    required this.sprintIds,
    this.sprintPerformanceData,
    this.sprintReportData,
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
    this.currentVersion = 0,
    this.versionHistory = const [],
    this.isArchived = false,
    this.archivedAt,
    this.sealedAt,
  });

  SignOffReport copyWith({
    String? id,
    String? deliverableId,
    String? reportTitle,
    String? reportContent,
    List<String>? sprintIds,
    String? sprintPerformanceData,
    Map<String, dynamic>? sprintReportData,
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
    int? currentVersion,
    List<dynamic>? versionHistory,
    bool? isArchived,
    DateTime? archivedAt,
    DateTime? sealedAt,
  }) {
    return SignOffReport(
      id: id ?? this.id,
      deliverableId: deliverableId ?? this.deliverableId,
      reportTitle: reportTitle ?? this.reportTitle,
      reportContent: reportContent ?? this.reportContent,
      sprintIds: sprintIds ?? this.sprintIds,
      sprintPerformanceData: sprintPerformanceData ?? this.sprintPerformanceData,
      sprintReportData: sprintReportData ?? this.sprintReportData,
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
      currentVersion: currentVersion ?? this.currentVersion,
      versionHistory: versionHistory ?? this.versionHistory,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: archivedAt ?? this.archivedAt,
      sealedAt: sealedAt ?? this.sealedAt,
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
      'sprintReportData': sprintReportData,
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
      'currentVersion': currentVersion,
      'versionHistory': versionHistory,
      'isArchived': isArchived,
      'archivedAt': archivedAt?.toIso8601String(),
      'sealedAt': sealedAt?.toIso8601String(),
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
    final String rawReportTitle = (json['reportTitle'] ?? json['report_title'] ?? '').toString();
    final String contentReportTitle = (content['reportTitle'] ?? '').toString();
    final String contentTitle = (content['title'] ?? '').toString();

    String? clientComment =
        (json['clientComment'] ??
                json['client_comment'] ??
                json['clientFeedback'] ??
                json['client_feedback'] ??
                content['clientComment'] ??
                content['client_comment'] ??
                json['comments'] ??
                json['comment'])
            ?.toString();
    String? changeRequestDetails =
        (json['changeRequestDetails'] ?? json['change_request_details'] ?? content['changeRequestDetails'] ?? content['change_request_details'])
            ?.toString();

    final reviewFeedbacks = <String>[];
    final reviewsRaw = json['reviews'] ?? content['reviews'];
    if (reviewsRaw is List) {
      for (final r in reviewsRaw) {
        if (r is! Map) continue;
        final m = Map<String, dynamic>.from(r);
        final status = (m['reviewStatus'] ?? m['status'] ?? m['review_status'] ?? '').toString().toLowerCase();
        final fb = (m['feedback'] ??
                m['comment'] ??
                m['clientComment'] ??
                m['client_comment'] ??
                m['changeRequestDetails'] ??
                m['change_request_details'])
            ?.toString();
        if (fb == null || fb.trim().isEmpty) continue;
        final v = fb.trim();
        reviewFeedbacks.add(v);
        if (status.contains('change')) {
          changeRequestDetails ??= v;
        } else {
          clientComment ??= v;
        }
      }
    }

    String reportTitle = () {
      int score(String s) {
        final v = s.trim();
        if (v.isEmpty) return -999;
        int sc = 100;
        if (!v.contains('\n')) sc += 30;
        if (v.length <= 80) sc += 25;
        if (v.length <= 120) sc += 10;
        if (v.length > 160) sc -= 60;
        if (v.contains('\n')) sc -= 90;
        final lower = v.toLowerCase();
        if (lower.contains('feedback') || lower.contains('comment') || lower.contains('approved') || lower.contains('request changes')) {
          sc -= 40;
        }
        final feedbacks = <String>[
          (clientComment ?? '').trim(),
          (changeRequestDetails ?? '').trim(),
          ...reviewFeedbacks,
        ].where((e) => e.isNotEmpty).toList();
        for (final c in feedbacks) {
          if (v == c) sc -= 120;
          if (c.length > 8 && v.contains(c)) sc -= 80;
        }
        sc -= (v.length ~/ 10);
        return sc;
      }

      final candidates = <String>[contentReportTitle, rawReportTitle, contentTitle]
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (candidates.isEmpty) return '';
      candidates.sort((a, b) => score(b).compareTo(score(a)));
      return candidates.first;
    }();
    final String reportContent = (json['reportContent'] ?? json['content_text'] ?? content['reportContent'] ?? content['content'] ?? '').toString();

    List<String> sprintIds = [];
    final dynamic sIds = json['sprintIds'] ?? json['sprint_ids'] ?? content['sprintIds'] ?? content['sprints'];
    if (sIds is List) {
      sprintIds = sIds.map((e) => e.toString()).toList();
    }

    final String? sprintPerformanceData =
        (json['sprintPerformanceData'] ?? content['sprintPerformanceData'])?.toString();
    final dynamic sprintReportDataRaw =
        json['sprintReportData'] ?? json['sprint_report_data'] ?? content['sprintReportData'] ?? content['sprint_report_data'];
    Map<String, dynamic>? sprintReportData = () {
      if (sprintReportDataRaw is Map) return Map<String, dynamic>.from(sprintReportDataRaw);
      if (sprintReportDataRaw is String && sprintReportDataRaw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(sprintReportDataRaw);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }
      return null;
    }();
    if ((sprintReportData == null || sprintReportData.isEmpty) && sprintPerformanceData != null && sprintPerformanceData.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(sprintPerformanceData);
        if (decoded is Map) sprintReportData = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }

    if (sprintReportData != null && sprintReportData.isNotEmpty) {
      final sprint = sprintReportData['sprint'];
      if (sprint is Map) {
        final sprintName = (sprint['name'] ?? '').toString().trim();
        if (sprintName.isNotEmpty) {
          final titleLower = reportTitle.trim().toLowerCase();
          final feedbackish = titleLower.contains('feedback') ||
              titleLower.contains('comment') ||
              titleLower.contains('change request') ||
              titleLower.contains('requested change') ||
              titleLower.startsWith('please ') ||
              reportTitle.trim() == (clientComment ?? '').trim() ||
              reportTitle.trim() == (changeRequestDetails ?? '').trim() ||
              reviewFeedbacks.contains(reportTitle.trim());
          if (feedbackish) {
            reportTitle = sprintName;
          }
        }
      }
    }
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

    String normalizeStatus(String raw) {
      final normalized = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
      switch (normalized) {
        case 'submitted':
          return 'submitted';
        case 'underreview':
          return 'underReview';
        case 'approved':
          return 'approved';
        case 'changerequested':
          return 'changeRequested';
        case 'rejected':
          return 'rejected';
        default:
          return 'draft';
      }
    }

    final String statusStr = normalizeStatus(
      (json['status'] ?? json['review_status'] ?? content['status'] ?? '').toString(),
    );
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
    final int currentVersion = int.tryParse(
          (json['currentVersion'] ?? json['current_version'] ?? content['currentVersion'] ?? 0).toString(),
        ) ??
        0;
    final List<dynamic> versionHistory =
        (json['versionHistory'] ?? json['version_history'] ?? content['versionHistory'] ?? const []) as List<dynamic>;
    final bool isArchived =
        (json['isArchived'] ?? json['is_archived'] ?? content['isArchived'] ?? false) == true;
    final String archivedAtStr =
        (json['archivedAt'] ?? json['archived_at'] ?? content['archivedAt'] ?? '').toString();
    final DateTime? archivedAt = archivedAtStr.isNotEmpty ? DateTime.tryParse(archivedAtStr) : null;
    final String sealedAtStr =
        (json['sealedAt'] ?? json['sealed_at'] ?? content['sealedAt'] ?? '').toString();
    final DateTime? sealedAt = sealedAtStr.isNotEmpty ? DateTime.tryParse(sealedAtStr) : null;

    return SignOffReport(
      id: id,
      deliverableId: deliverableId,
      reportTitle: reportTitle,
      reportContent: reportContent,
      sprintIds: sprintIds,
      sprintPerformanceData: sprintPerformanceData,
      sprintReportData: sprintReportData,
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
      currentVersion: currentVersion,
      versionHistory: versionHistory,
      isArchived: isArchived,
      archivedAt: archivedAt,
      sealedAt: sealedAt,
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

  Map<String, dynamic>? get effectiveSprintReportData {
    final d = sprintReportData;
    if (d != null && d.isNotEmpty) return d;
    final raw = sprintPerformanceData;
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  String get displayTitle {
    final d = effectiveSprintReportData;
    if (d != null) {
      final dynamic v = d['reportTitle'] ?? d['report_title'] ?? d['aiTitle'] ?? d['suggestedTitle'] ?? d['title'];
      final s = v?.toString().trim() ?? '';
      if (s.isNotEmpty) return s;
    }

    final t = reportTitle.trim();
    if (t.isEmpty) return d != null ? 'Sprint Sign-Off Report' : 'Sign-Off Report';

    final comment = (clientComment ?? '').trim();
    final changeReq = (changeRequestDetails ?? '').trim();
    final lower = t.toLowerCase();
    final looksLikeFeedback =
        t.contains('\n') ||
        t.length > 160 ||
        (comment.isNotEmpty && (t == comment || t.contains(comment))) ||
        (changeReq.isNotEmpty && (t == changeReq || t.contains(changeReq))) ||
        lower.contains('feedback') ||
        lower.contains('comment') ||
        lower.contains('change request') ||
        lower.contains('requested change');

    if (!looksLikeFeedback) return t;
    if (d != null) return 'Sprint Sign-Off Report';
    return 'Sign-Off Report';
  }
}
