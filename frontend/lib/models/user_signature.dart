import 'dart:convert';
import 'package:flutter/foundation.dart';

/// User signature model
/// Represents a saved user signature for reuse in document signing
class UserSignature {
  final String id;
  final String userId;
  final String signatureData; // Base64 encoded signature
  final String signatureType; // 'drawn', 'typed', 'uploaded'
  final bool isDefault;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastUsedAt;
  final String? userName;
  final String? userEmail;

  const UserSignature({
    required this.id,
    required this.userId,
    required this.signatureData,
    required this.signatureType,
    required this.isDefault,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.lastUsedAt,
    this.userName,
    this.userEmail,
  });

  factory UserSignature.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    String readString(String key, {String fallback = ''}) {
      final v = json[key];
      if (v == null) return fallback;
      return v.toString();
    }

    bool readBool(String key, {bool fallback = false}) {
      final v = json[key];
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final t = v.trim().toLowerCase();
        if (t == 'true' || t == '1' || t == 'yes') return true;
        if (t == 'false' || t == '0' || t == 'no') return false;
      }
      return fallback;
    }

    DateTime readDate(String key, {DateTime? fallback}) {
      final v = json[key];
      if (v == null) return fallback ?? now;
      if (v is DateTime) return v;
      if (v is String) {
        try {
          return DateTime.parse(v);
        } catch (_) {
          return fallback ?? now;
        }
      }
      return fallback ?? now;
    }

    final user = json['user'];
    String? userName;
    String? userEmail;
    if (user is Map) {
      final first = (user['first_name'] ?? '').toString().trim();
      final last = (user['last_name'] ?? '').toString().trim();
      final combined = ('$first $last').trim();
      userName = combined.isEmpty ? null : combined;
      final e = user['email'];
      userEmail = e?.toString();
    } else {
      final n = json['user_name'] ?? json['userName'];
      userName = n?.toString();
      final e = json['user_email'] ?? json['userEmail'];
      userEmail = e?.toString();
    }

    return UserSignature(
      id: readString('id'),
      userId: readString('user_id', fallback: readString('userId', fallback: '')),
      signatureData: readString('signature_data', fallback: readString('signatureData', fallback: '')),
      signatureType: readString('signature_type', fallback: readString('signatureType', fallback: '')),
      isDefault: readBool('is_default', fallback: readBool('isDefault', fallback: false)),
      isActive: readBool('is_active', fallback: readBool('isActive', fallback: true)),
      createdAt: readDate('created_at'),
      updatedAt: readDate('updated_at'),
      lastUsedAt: json['last_used_at'] != null ? readDate('last_used_at') : null,
      userName: userName,
      userEmail: userEmail,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'signature_data': signatureData,
      'signature_type': signatureType,
      'is_default': isDefault,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (lastUsedAt != null) 'last_used_at': lastUsedAt!.toIso8601String(),
      if (userName != null) 'user_name': userName,
      if (userEmail != null) 'user_email': userEmail,
    };
  }

  /// Get signature data as bytes for display
  Uint8List get signatureDataBytes {
    try {
      // Remove data URL prefix if present
      String base64String = signatureData;
      if (base64String.contains(',')) {
        base64String = base64String.split(',').last;
      }
      return base64Decode(base64String);
    } catch (e) {
      debugPrint('Error decoding signature data: $e');
      return Uint8List(0);
    }
  }

  /// Get formatted signature type display name
  String get signatureTypeDisplay {
    switch (signatureType.toLowerCase()) {
      case 'drawn':
        return 'Drawn Signature';
      case 'typed':
        return 'Typed Signature';
      case 'uploaded':
        return 'Uploaded Signature';
      default:
        return 'Signature';
    }
  }

  /// Check if signature is recently used (within last 30 days)
  bool get isRecentlyUsed {
    if (lastUsedAt == null) return false;
    final now = DateTime.now();
    final difference = now.difference(lastUsedAt!);
    return difference.inDays <= 30;
  }

  /// Create a copy with updated fields
  UserSignature copyWith({
    String? id,
    String? userId,
    String? signatureData,
    String? signatureType,
    bool? isDefault,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastUsedAt,
    String? userName,
    String? userEmail,
  }) {
    return UserSignature(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      signatureData: signatureData ?? this.signatureData,
      signatureType: signatureType ?? this.signatureType,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserSignature && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'UserSignature(id: $id, type: $signatureType, isDefault: $isDefault)';
  }
}
