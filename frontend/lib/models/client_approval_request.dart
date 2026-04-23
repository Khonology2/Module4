enum ClientApprovalStatus { pending, approved, rejected, reminderSent }

class ClientApprovalRequest {
  final String id;
  final String deliverableId;
  final String deliverableTitle;
  final String clientId;
  final String clientName;
  final String deliveryManagerId;
  final String deliveryManagerName;
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final ClientApprovalStatus status;
  final String? comments;
  final List<DateTime> reminderSentAt;
  final DateTime? dueDate;

  ClientApprovalRequest({
    required this.id,
    required this.deliverableId,
    required this.deliverableTitle,
    required this.clientId,
    required this.clientName,
    required this.deliveryManagerId,
    required this.deliveryManagerName,
    required this.requestedAt,
    this.approvedAt,
    this.rejectedAt,
    required this.status,
    this.comments,
    List<DateTime>? reminderSentAt,
    this.dueDate,
  }) : reminderSentAt = reminderSentAt ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'deliverableId': deliverableId,
    'deliverableTitle': deliverableTitle,
    'clientId': clientId,
    'clientName': clientName,
    'deliveryManagerId': deliveryManagerId,
    'deliveryManagerName': deliveryManagerName,
    'requestedAt': requestedAt.toIso8601String(),
    'approvedAt': approvedAt?.toIso8601String(),
    'rejectedAt': rejectedAt?.toIso8601String(),
    'status': status.name,
    'comments': comments,
    'reminderSentAt': reminderSentAt.map((d) => d.toIso8601String()).toList(),
    'dueDate': dueDate?.toIso8601String(),
  };

  factory ClientApprovalRequest.fromJson(Map<String, dynamic> json) => ClientApprovalRequest(
    id: json['id'],
    deliverableId: json['deliverableId'],
    deliverableTitle: json['deliverableTitle'],
    clientId: json['clientId'],
    clientName: json['clientName'],
    deliveryManagerId: json['deliveryManagerId'],
    deliveryManagerName: json['deliveryManagerName'],
    requestedAt: DateTime.parse(json['requestedAt']),
    approvedAt: json['approvedAt'] != null ? DateTime.parse(json['approvedAt']) : null,
    rejectedAt: json['rejectedAt'] != null ? DateTime.parse(json['rejectedAt']) : null,
    status: ClientApprovalStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => ClientApprovalStatus.pending),
    comments: json['comments'],
    reminderSentAt: (json['reminderSentAt'] as List<dynamic>? ?? []).map((e) => DateTime.parse(e)).toList(),
    dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
  );

  ClientApprovalRequest copyWith({
    String? id,
    String? deliverableId,
    String? deliverableTitle,
    String? clientId,
    String? clientName,
    String? deliveryManagerId,
    String? deliveryManagerName,
    DateTime? requestedAt,
    DateTime? approvedAt,
    DateTime? rejectedAt,
    ClientApprovalStatus? status,
    String? comments,
    List<DateTime>? reminderSentAt,
    DateTime? dueDate,
  }) => ClientApprovalRequest(
    id: id ?? this.id,
    deliverableId: deliverableId ?? this.deliverableId,
    deliverableTitle: deliverableTitle ?? this.deliverableTitle,
    clientId: clientId ?? this.clientId,
    clientName: clientName ?? this.clientName,
    deliveryManagerId: deliveryManagerId ?? this.deliveryManagerId,
    deliveryManagerName: deliveryManagerName ?? this.deliveryManagerName,
    requestedAt: requestedAt ?? this.requestedAt,
    approvedAt: approvedAt ?? this.approvedAt,
    rejectedAt: rejectedAt ?? this.rejectedAt,
    status: status ?? this.status,
    comments: comments ?? this.comments,
    reminderSentAt: reminderSentAt ?? this.reminderSentAt,
    dueDate: dueDate ?? this.dueDate,
  );

  bool get isPending => status == ClientApprovalStatus.pending;
  bool get isApproved => status == ClientApprovalStatus.approved;
  bool get isRejected => status == ClientApprovalStatus.rejected;
  bool get isReminderSent => status == ClientApprovalStatus.reminderSent;
  
  int get daysSinceRequest => DateTime.now().difference(requestedAt).inDays;
  
  bool get isOverdue => dueDate != null && DateTime.now().isAfter(dueDate!);
  
  int get daysUntilDue => dueDate != null ? dueDate!.difference(DateTime.now()).inDays : 0;
  
  bool shouldSendReminder() {
    if (!isPending) return false;
    if (reminderSentAt.isNotEmpty) {
      return DateTime.now().difference(reminderSentAt.last).inDays >= 2;
    }
    return daysSinceRequest >= 3;
  }
}