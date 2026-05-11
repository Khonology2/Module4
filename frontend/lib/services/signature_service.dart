import 'package:flutter/foundation.dart';
import 'api_client.dart';
import '../models/user_signature.dart';

/// Enhanced signature service with reusable signature support
/// Manages user signatures, DocuSign integration, and audit trail
class SignatureService {
  final ApiClient _apiClient;

  SignatureService(this._apiClient);

  /// Get all signatures for authenticated user
  Future<List<UserSignature>> getUserSignatures() async {
    try {
      final response = await _apiClient.get('/signatures');

      if (response.isSuccess && response.data != null) {
        final responseData = response.data!;
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
      return [];
    } catch (e) {
      debugPrint('Error fetching user signatures: $e');
      throw Exception('Failed to fetch signatures: $e');
    }
  }

  /// Get user's default signature
  Future<UserSignature?> getDefaultSignature() async {
    try {
      final response = await _apiClient.get('/signatures/default');

      if (response.isSuccess && response.data != null) {
        return UserSignature.fromJson(response.data!['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching default signature: $e');
      return null;
    }
  }

  /// Save a new signature for user
  Future<UserSignature> saveSignature(
    String signatureData,
    String signatureType,
    bool isDefault,
  ) async {
    try {
      final response = await _apiClient.post(
        '/signatures',
        body: {
          'signatureData': signatureData,
          'signatureType': signatureType,
          'isDefault': isDefault,
        },
      );

      if (response.isSuccess && response.data != null) {
        // Handle both direct data and nested data formats
        final responseData = response.data!;
        if (responseData is Map<String, dynamic>) {
          final signatureData = responseData['data'] ?? responseData;
          if (signatureData is Map<String, dynamic>) {
            return UserSignature.fromJson(signatureData);
          }
        }
      }
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
      final response = await _apiClient.put(
        '/signatures/$signatureId',
        body: updates,
      );

      if (response.isSuccess && response.data != null) {
        return UserSignature.fromJson(response.data!['data']);
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
      final response = await _apiClient.delete('/signatures/$signatureId');
      return response.isSuccess;
    } catch (e) {
      debugPrint('Error deleting signature: $e');
      return false;
    }
  }

  /// Set signature as default
  Future<UserSignature> setDefaultSignature(String signatureId) async {
    try {
      final response = await _apiClient.post(
        '/signatures/$signatureId/set-default',
        body: {},
      );

      if (response.isSuccess && response.data != null) {
        return UserSignature.fromJson(response.data!['data']);
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
      final response = await _apiClient.get('/signatures/$signatureId');
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
