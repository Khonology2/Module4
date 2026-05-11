import '../models/docusign_config.dart';
import 'api_client.dart';
import 'package:flutter/foundation.dart';

/// Service for DocuSign e-signature integration
/// Handles envelope creation, sending, and status tracking
class DocuSignService {
  final ApiClient _apiClient;
  DocuSignConfig? _config;

  DocuSignService(this._apiClient);

  /// Load DocuSign configuration from backend
  Future<bool> loadConfiguration() async {
    try {
      final response = await _apiClient.get('/docusign/config');
      if (response.isSuccess && response.data != null) {
        _config = DocuSignConfig.fromJson(response.data!);
        return _config!.isConfigured;
      }
      return false;
    } catch (e) {
      debugPrint('Error loading DocuSign config: $e');
      return false;
    }
  }

  /// Check if DocuSign is configured and ready to use
  bool get isConfigured => _config != null && _config!.isConfigured;

  /// Create and send DocuSign envelope for report signing
  /// Returns envelope ID if successful
  Future<String?> createEnvelopeForReport({
    required String reportId,
    required String signerEmail,
    required String signerName,
    required String reportTitle,
    required String reportContent,
  }) async {
    try {
      if (!isConfigured) {
        throw Exception('DocuSign is not configured');
      }

      // Call backend to create envelope
      // Backend will handle DocuSign API authentication and envelope creation
      final response = await _apiClient.post(
        '/docusign/envelopes/create',
        body: {
          'reportId': reportId,
          'signerEmail': signerEmail,
          'signerName': signerName,
          'reportTitle': reportTitle,
          'reportContent': reportContent,
        },
      );

      if (response.isSuccess && response.data != null) {
        final envelopeId = response.data!['envelopeId'] as String?;
        debugPrint('✅ DocuSign envelope created: $envelopeId');
        return envelopeId;
      } else {
        debugPrint('❌ Failed to create DocuSign envelope: ${response.error}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error creating DocuSign envelope: $e');
      return null;
    }
  }

  /// Get envelope status
  Future<DocuSignEnvelope?> getEnvelopeStatus(String reportId) async {
    try {
      final response = await _apiClient.get('/docusign/envelopes/$reportId/status');
      
      if (response.isSuccess && response.data != null) {
        return DocuSignEnvelope.fromJson(response.data!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting envelope status: $e');
      return null;
    }
  }

  /// Get all envelopes for a report
  Future<List<DocuSignEnvelope>> getReportEnvelopes(String reportId) async {
    try {
      final response = await _apiClient.get('/docusign/envelopes/$reportId');
      
      if (response.isSuccess && response.data != null) {
        final envelopes = response.data!['envelopes'] as List;
        return envelopes.map((e) => DocuSignEnvelope.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting report envelopes: $e');
      return [];
    }
  }

  /// Resend envelope to signer
  Future<bool> resendEnvelope(String envelopeId) async {
    try {
      final response = await _apiClient.post(
        '/docusign/envelopes/$envelopeId/resend',
        body: {},
      );
      return response.isSuccess;
    } catch (e) {
      debugPrint('Error resending envelope: $e');
      return false;
    }
  }

  /// Void (cancel) an envelope
  Future<bool> voidEnvelope(String envelopeId, String reason) async {
    try {
      final response = await _apiClient.post(
        '/docusign/envelopes/$envelopeId/void',
        body: {'reason': reason},
      );
      return response.isSuccess;
    } catch (e) {
      debugPrint('Error voiding envelope: $e');
      return false;
    }
  }

  /// Get signing URL for embedded signing (optional feature)
  Future<String?> getEmbeddedSigningUrl({
    required String envelopeId,
    required String signerEmail,
    required String returnUrl,
  }) async {
    try {
      final response = await _apiClient.post(
        '/docusign/envelopes/$envelopeId/signing-url',
        body: {
          'signerEmail': signerEmail,
          'returnUrl': returnUrl,
        },
      );

      if (response.isSuccess && response.data != null) {
        return response.data!['url'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting signing URL: $e');
      return null;
    }
  }
}
