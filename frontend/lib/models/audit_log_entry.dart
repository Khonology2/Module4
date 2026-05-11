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
    String? pickString(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    Map<String, dynamic>? pickMap(dynamic v) {
      if (v == null) return null;
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      if (v is String) {
        try {
          final decoded = jsonDecode(v);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }
      return null;
    }

    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      final s = v.toString();
      try {
        return DateTime.parse(s);
      } catch (_) {
        return DateTime.now();
      }
    }

    final userMap = pickMap(json['user']) ?? pickMap(json['actor']) ?? pickMap(json['performed_by']);
    final actorEmail = pickString(json['user_email']) ??
        pickString(json['userEmail']) ??
        pickString(json['actor_email']) ??
        pickString(json['actorEmail']) ??
        pickString(userMap?['email']);
    final actorRole = pickString(json['user_role']) ??
        pickString(json['userRole']) ??
        pickString(json['actor_role']) ??
        pickString(json['actorRole']) ??
        pickString(userMap?['role']);
    final actorId = pickString(json['user_id']) ??
        pickString(json['userId']) ??
        pickString(json['actor_id']) ??
        pickString(json['actorId']) ??
        pickString(userMap?['id']) ??
        pickString(userMap?['user_id']) ??
        pickString(userMap?['userId']);

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
      userId: actorId,
      userEmail: actorEmail,
      userRole: actorRole,
      action: json['action']?.toString() ?? 'unknown',
      actionCategory: json['action_category']?.toString() ?? json['actionCategory']?.toString(),
      entityType: json['entity_type']?.toString() ?? json['entityType']?.toString(),
      entityId: json['entity_id']?.toString() ?? json['entityId']?.toString(),
      oldValues: parseMap(json['old_values'] ?? json['oldValues']),
      newValues: parseMap(json['new_values'] ?? json['newValues']),
      changedFields: parseList(json['changed_fields'] ?? json['changedFields']),
      createdAt: parseDate(json['created_at'] ?? json['createdAt'] ?? json['timestamp']),
    );
  }
}
