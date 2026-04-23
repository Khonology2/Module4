import 'dart:convert';

class AuditLogEntry {
  final int id;
  final String? userId;
  final String? userEmail;
  final String? userRole;
  final String action;
  final String? actionCategory;
  final String? entityType;
  final String? entityId;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final List<String>? changedFields;
  final DateTime createdAt;

  const AuditLogEntry({
    required this.id,
    this.userId,
    this.userEmail,
    this.userRole,
    required this.action,
    this.actionCategory,
    this.entityType,
    this.entityId,
    this.oldValues,
    this.newValues,
    this.changedFields,
    required this.createdAt,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parseMap(dynamic value) {
      if (value == null) return null;
      if (value is Map<String, dynamic>) return value;
      if (value is String) {
        try {
          return jsonDecode(value) as Map<String, dynamic>;
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    List<String>? parseList(dynamic value) {
      if (value == null) return null;
      if (value is List) return value.map((e) => e.toString()).toList();
      if (value is Map) return value.keys.map((e) => e.toString()).toList();
      if (value is String) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) return decoded.map((e) => e.toString()).toList();
          if (decoded is Map) return decoded.keys.map((e) => e.toString()).toList();
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    return AuditLogEntry(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      userId: json['user_id']?.toString() ?? json['userId']?.toString(),
      userEmail: json['user_email']?.toString() ?? json['userEmail']?.toString(),
      userRole: json['user_role']?.toString() ?? json['userRole']?.toString(),
      action: json['action']?.toString() ?? 'unknown',
      actionCategory: json['action_category']?.toString() ?? json['actionCategory']?.toString(),
      entityType: json['entity_type']?.toString() ?? json['entityType']?.toString(),
      entityId: json['entity_id']?.toString() ?? json['entityId']?.toString(),
      oldValues: parseMap(json['old_values'] ?? json['oldValues']),
      newValues: parseMap(json['new_values'] ?? json['newValues']),
      changedFields: parseList(json['changed_fields'] ?? json['changedFields']),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'].toString()) 
          : DateTime.now(),
    );
  }
}
