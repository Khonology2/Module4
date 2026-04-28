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
    return UserSignature(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      signatureData: json['signature_data'] as String,
      signatureType: json['signature_type'] as String,
      isDefault: json['is_default'] as bool,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastUsedAt: json['last_used_at'] != null 
          ? DateTime.parse(json['last_used_at'] as String) 
          : null,
      userName: json['user']?['first_name'] != null 
          ? '${json['user']['first_name']} ${json['user']['last_name']}'
          : null,
      userEmail: json['user']?['email'] as String?,
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
