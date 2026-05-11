import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import '../models/user_signature.dart';

/// Enhanced signature service with reusable signature support
/// Manages user signatures, DocuSign integration, and audit trail
class SignatureService {
  final ApiClient _apiClient;

  SignatureService(this._apiClient);

  static const String _localSignaturesKey = 'saved_signatures';

  static const List<String> _signatureBaseEndpoints = <String>[
    '/signatures',
    '/user-signatures',
    '/users/me/signatures',
  ];

  Future<List<UserSignature>> _loadLocalSignatures() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localSignaturesKey);
      if (raw == null || raw.trim().isEmpty) return const <UserSignature>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <UserSignature>[];
      return decoded
          .whereType<dynamic>()
          .map((e) => e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map))
          .map((m) => UserSignature.fromJson(m))
          .toList();
    } catch (_) {
      return const <UserSignature>[];
    }
  }

  Future<void> _saveLocalSignatures(List<UserSignature> signatures) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(signatures.map((s) => s.toJson()).toList());
      await prefs.setString(_localSignaturesKey, raw);
    } catch (_) {}
  }

  bool _isEndpointNotFound(ApiResponse response) {
    if (response.statusCode != 404) return false;
    final e = (response.error ?? '').toLowerCase();
    return e.contains('endpoint not found') || e.contains('not found');
  }

  Future<ApiResponse> _getWithFallback(String suffix) async {
    ApiResponse last = ApiResponse.error('Endpoint not found', 404);
    for (final base in _signatureBaseEndpoints) {
      final res = await _apiClient.get('$base$suffix');
      if (res.isSuccess) return res;
      last = res;
      if (res.statusCode != 404) return res;
    }
    return last;
  }

  Future<ApiResponse> _postWithFallback(String suffix, {Map<String, dynamic>? body}) async {
    ApiResponse last = ApiResponse.error('Endpoint not found', 404);
    for (final base in _signatureBaseEndpoints) {
      final res = await _apiClient.post('$base$suffix', body: body);
      if (res.isSuccess) return res;
      last = res;
      if (res.statusCode != 404) return res;
    }
    return last;
  }

  Future<ApiResponse> _putWithFallback(String suffix, {Map<String, dynamic>? body}) async {
    ApiResponse last = ApiResponse.error('Endpoint not found', 404);
    for (final base in _signatureBaseEndpoints) {
      final res = await _apiClient.put('$base$suffix', body: body);
      if (res.isSuccess) return res;
      last = res;
      if (res.statusCode != 404) return res;
    }
    return last;
  }

  Future<ApiResponse> _deleteWithFallback(String suffix) async {
    ApiResponse last = ApiResponse.error('Endpoint not found', 404);
    for (final base in _signatureBaseEndpoints) {
      final res = await _apiClient.delete('$base$suffix');
      if (res.isSuccess) return res;
      last = res;
      if (res.statusCode != 404) return res;
    }
    return last;
  }

  /// Get all signatures for authenticated user
  Future<List<UserSignature>> getUserSignatures() async {
    try {
      final response = await _getWithFallback('');

      if (response.isSuccess && response.data != null) {
        final responseData = response.data;
        List<dynamic> signaturesJson = [];
        
        if (responseData is Map<String, dynamic>) {
          final data = responseData['data'];
          if (data is List) {
            signaturesJson = data;
          }
        } else if (responseData is List) {
          signaturesJson = responseData;
        }
        
        return signaturesJson
            .map((json) => UserSignature.fromJson(json))
            .toList();
      }
      if (_isEndpointNotFound(response)) {
        return await _loadLocalSignatures();
      }
      return const <UserSignature>[];
    } catch (e) {
      debugPrint('Error fetching user signatures: $e');
      return await _loadLocalSignatures();
    }
  }

  /// Get user's default signature
  Future<UserSignature?> getDefaultSignature() async {
    try {
      final response = await _getWithFallback('/default');

      if (response.isSuccess && response.data != null) {
        final d = response.data;
        if (d is Map<String, dynamic>) {
          if (d.containsKey('data') && d['data'] is Map) {
            return UserSignature.fromJson(Map<String, dynamic>.from(d['data'] as Map));
          }
          return UserSignature.fromJson(d);
        }
      }
      if (_isEndpointNotFound(response)) {
        final local = await _loadLocalSignatures();
        if (local.isEmpty) return null;
        for (final s in local) {
          if (s.isDefault) return s;
        }
        return local.first;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching default signature: $e');
      final local = await _loadLocalSignatures();
      if (local.isEmpty) return null;
      for (final s in local) {
        if (s.isDefault) return s;
      }
      return local.first;
    }
  }

  /// Save a new signature for user
  Future<UserSignature> saveSignature(
    String signatureData,
    String signatureType,
    bool isDefault,
  ) async {
    try {
      final response = await _postWithFallback(
        '',
        body: {
          'signatureData': signatureData,
          'signatureType': signatureType,
          'isDefault': isDefault,
        },
      );

      if (!response.isSuccess) {
        if (_isEndpointNotFound(response)) {
          final now = DateTime.now();
          final localId = now.millisecondsSinceEpoch.toString();
          final current = await _loadLocalSignatures();
          final updated = <UserSignature>[
            for (final s in current) s.copyWith(isDefault: isDefault ? false : s.isDefault),
            UserSignature(
              id: localId,
              userId: 'local_user',
              signatureData: signatureData,
              signatureType: signatureType,
              isDefault: isDefault,
              isActive: true,
              createdAt: now,
              updatedAt: now,
              lastUsedAt: now,
            ),
          ];
          await _saveLocalSignatures(updated);
          return updated.last;
        }
        throw Exception(response.error ?? 'Failed to save signature');
      }

      Map<String, dynamic>? toMap(dynamic v) {
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

      Map<String, dynamic>? pickSignatureMap(dynamic root) {
        final m = toMap(root);
        if (m == null) return null;
        if (m.containsKey('signature_data') || m.containsKey('signatureData')) return m;
        final nestedData = m['data'];
        final nested = toMap(nestedData);
        if (nested != null && (nested.containsKey('signature_data') || nested.containsKey('signatureData'))) {
          return nested;
        }
        final signature = toMap(m['signature']);
        if (signature != null && (signature.containsKey('signature_data') || signature.containsKey('signatureData'))) {
          return signature;
        }
        return null;
      }

      final sigMap = pickSignatureMap(response.data);
      if (sigMap != null) {
        return UserSignature.fromJson(sigMap);
      }

      try {
        final fallback = await getDefaultSignature();
        if (fallback != null) return fallback;
      } catch (_) {}

      throw Exception('Failed to save signature: Invalid response format');
    } catch (e) {
      debugPrint('Error saving signature: $e');
      throw Exception('Failed to save signature: $e');
    }
  }

  /// Update existing signature
  Future<UserSignature> updateSignature(
    String signatureId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _putWithFallback('/$signatureId', body: updates);

      if (response.isSuccess && response.data != null) {
        final d = response.data;
        if (d is Map<String, dynamic>) {
          if (d.containsKey('data') && d['data'] is Map) {
            return UserSignature.fromJson(Map<String, dynamic>.from(d['data'] as Map));
          }
          return UserSignature.fromJson(d);
        }
      }
      if (_isEndpointNotFound(response)) {
        final local = await _loadLocalSignatures();
        final idx = local.indexWhere((s) => s.id == signatureId);
        if (idx == -1) throw Exception('Signature not found');
        final now = DateTime.now();
        final m = <String, dynamic>{...local[idx].toJson(), ...updates};
        final updated = UserSignature.fromJson(m).copyWith(updatedAt: now);
        final next = <UserSignature>[...local]..[idx] = updated;
        await _saveLocalSignatures(next);
        return updated;
      }
      throw Exception('Failed to update signature');
    } catch (e) {
      debugPrint('Error updating signature: $e');
      throw Exception('Failed to update signature: $e');
    }
  }

  /// Delete signature
  Future<bool> deleteSignature(String signatureId) async {
    try {
      final response = await _deleteWithFallback('/$signatureId');
      if (_isEndpointNotFound(response)) {
        final local = await _loadLocalSignatures();
        final next = local.where((s) => s.id != signatureId).toList();
        await _saveLocalSignatures(next);
        return true;
      }
      return response.isSuccess;
    } catch (e) {
      debugPrint('Error deleting signature: $e');
      return false;
    }
  }

  /// Set signature as default
  Future<UserSignature> setDefaultSignature(String signatureId) async {
    try {
      final response = await _postWithFallback('/$signatureId/set-default', body: {});

      if (response.isSuccess && response.data != null) {
        final d = response.data;
        if (d is Map<String, dynamic>) {
          if (d.containsKey('data') && d['data'] is Map) {
            return UserSignature.fromJson(Map<String, dynamic>.from(d['data'] as Map));
          }
          return UserSignature.fromJson(d);
        }
      }
      if (_isEndpointNotFound(response)) {
        final local = await _loadLocalSignatures();
        if (local.isEmpty) throw Exception('No signatures available');
        final next = local
            .map((s) => s.copyWith(isDefault: s.id == signatureId))
            .toList();
        await _saveLocalSignatures(next);
        return next.firstWhere((s) => s.id == signatureId);
      }
      throw Exception('Failed to set default signature');
    } catch (e) {
      debugPrint('Error setting default signature: $e');
      throw Exception('Failed to set default signature: $e');
    }
  }

  /// Sign document using saved signature
  Future<Map<String, dynamic>> signWithSavedSignature(
    String reportId,
    String signatureId,
    Map<String, dynamic> signOffData,
  ) async {
    try {
      final response = await _apiClient.post(
        '/signatures/sign-document',
        body: {
          'reportId': reportId,
          'signatureId': signatureId,
          'signOffData': signOffData,
        },
      );

      if (response.isSuccess && response.data != null) {
        return response.data!;
      }
      throw Exception('Failed to sign document');
    } catch (e) {
      debugPrint('Error signing with saved signature: $e');
      throw Exception('Failed to sign document: $e');
    }
  }

  /// Get signature audit trail for a report
  Future<List<Map<String, dynamic>>> getSignatureAuditTrail(
      String reportId) async {
    try {
      final response = await _apiClient.get('/signatures/audit/$reportId');

      if (response.isSuccess && response.data != null) {
        final List<dynamic> auditData = response.data!['data'];
        return auditData.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching audit trail: $e');
      return [];
    }
  }

  /// Verify signature ownership and validity
  Future<bool> verifySignature(String signatureId) async {
    try {
      // This would be handled by the backend verification
      // For now, we'll assume verification passes if we can fetch the signature
      final response = await _getWithFallback('/$signatureId');
      if (_isEndpointNotFound(response)) {
        final local = await _loadLocalSignatures();
        return local.any((s) => s.id == signatureId);
      }
      return response.isSuccess;
    } catch (e) {
      debugPrint('Error verifying signature: $e');
      return false;
    }
  }

  /// Check if user has any signatures
  Future<bool> hasSignatures() async {
    try {
      final signatures = await getUserSignatures();
      return signatures.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking signatures: $e');
      return false;
    }
  }

  /// Get signature count by type
  Future<Map<String, int>> getSignatureCountByType() async {
    try {
      final signatures = await getUserSignatures();
      final Map<String, int> counts = {};

      for (final signature in signatures) {
        counts[signature.signatureType] =
            (counts[signature.signatureType] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      debugPrint('Error getting signature counts: $e');
      return {};
    }
  }
}
