/// DocuSign configuration model
/// Stores API credentials and settings for DocuSign integration
class DocuSignConfig {
  final String integrationKey; // DocuSign API Integration Key (Client ID)
  final String secretKey; // DocuSign API Secret Key
  final String accountId; // DocuSign Account ID
  final String userId; // DocuSign User ID (GUID)
  final String baseUrl; // DocuSign API base URL (demo or production)
  final bool isProduction; // Whether to use production or demo environment
  final String? rsaPrivateKey; // RSA private key for JWT authentication (optional)
  
  const DocuSignConfig({
    required this.integrationKey,
    required this.secretKey,
    required this.accountId,
    required this.userId,
    required this.baseUrl,
    this.isProduction = false,
    this.rsaPrivateKey,
  });

  factory DocuSignConfig.fromJson(Map<String, dynamic> json) {
    return DocuSignConfig(
      integrationKey: json['integration_key'] as String,
      secretKey: json['secret_key'] as String,
      accountId: json['account_id'] as String,
      userId: json['user_id'] as String,
      baseUrl: json['base_url'] as String,
      isProduction: json['is_production'] as bool? ?? false,
      rsaPrivateKey: json['rsa_private_key'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'integration_key': integrationKey,
      'secret_key': secretKey,
      'account_id': accountId,
      'user_id': userId,
      'base_url': baseUrl,
      'is_production': isProduction,
      if (rsaPrivateKey != null) 'rsa_private_key': rsaPrivateKey,
    };
  }

  // Demo environment config
  factory DocuSignConfig.demo({
    required String integrationKey,
    required String secretKey,
    required String accountId,
    required String userId,
    String? rsaPrivateKey,
  }) {
    return DocuSignConfig(
      integrationKey: integrationKey,
      secretKey: secretKey,
      accountId: accountId,
      userId: userId,
      baseUrl: 'https://demo.docusign.net/restapi',
      isProduction: false,
      rsaPrivateKey: rsaPrivateKey,
    );
  }

  // Production environment config
  factory DocuSignConfig.production({
    required String integrationKey,
    required String secretKey,
    required String accountId,
    required String userId,
    String? rsaPrivateKey,
  }) {
    return DocuSignConfig(
      integrationKey: integrationKey,
      secretKey: secretKey,
      accountId: accountId,
      userId: userId,
      baseUrl: 'https://www.docusign.net/restapi',
      isProduction: true,
      rsaPrivateKey: rsaPrivateKey,
    );
  }

  bool get isConfigured {
    return integrationKey.isNotEmpty &&
           secretKey.isNotEmpty &&
           accountId.isNotEmpty &&
           userId.isNotEmpty;
  }
}

/// DocuSign envelope status
enum DocuSignEnvelopeStatus {
  created,
  sent,
  delivered,
  signed,
  completed,
  declined,
  voided,
  unknown;

  static DocuSignEnvelopeStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'created':
        return DocuSignEnvelopeStatus.created;
      case 'sent':
        return DocuSignEnvelopeStatus.sent;
      case 'delivered':
        return DocuSignEnvelopeStatus.delivered;
      case 'signed':
        return DocuSignEnvelopeStatus.signed;
      case 'completed':
        return DocuSignEnvelopeStatus.completed;
      case 'declined':
        return DocuSignEnvelopeStatus.declined;
      case 'voided':
        return DocuSignEnvelopeStatus.voided;
      default:
        return DocuSignEnvelopeStatus.unknown;
    }
  }

  String get displayName {
    switch (this) {
      case DocuSignEnvelopeStatus.created:
        return 'Created';
      case DocuSignEnvelopeStatus.sent:
        return 'Sent';
      case DocuSignEnvelopeStatus.delivered:
        return 'Delivered';
      case DocuSignEnvelopeStatus.signed:
        return 'Signed';
      case DocuSignEnvelopeStatus.completed:
        return 'Completed';
      case DocuSignEnvelopeStatus.declined:
        return 'Declined';
      case DocuSignEnvelopeStatus.voided:
        return 'Voided';
      case DocuSignEnvelopeStatus.unknown:
        return 'Unknown';
    }
  }
}

/// DocuSign envelope model
class DocuSignEnvelope {
  final String id;
  final String reportId;
  final String envelopeId;
  final String signerEmail;
  final String signerName;
  final DocuSignEnvelopeStatus status;
  final DateTime createdAt;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? signedAt;
  final DateTime? completedAt;
  final String? declineReason;

  const DocuSignEnvelope({
    required this.id,
    required this.reportId,
    required this.envelopeId,
    required this.signerEmail,
    required this.signerName,
    required this.status,
    required this.createdAt,
    this.sentAt,
    this.deliveredAt,
    this.signedAt,
    this.completedAt,
    this.declineReason,
  });

  factory DocuSignEnvelope.fromJson(Map<String, dynamic> json) {
    return DocuSignEnvelope(
      id: json['id'] as String,
      reportId: json['report_id'] as String,
      envelopeId: json['envelope_id'] as String,
      signerEmail: json['signer_email'] as String,
      signerName: json['signer_name'] as String,
      status: DocuSignEnvelopeStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      sentAt: json['sent_at'] != null ? DateTime.parse(json['sent_at'] as String) : null,
      deliveredAt: json['delivered_at'] != null ? DateTime.parse(json['delivered_at'] as String) : null,
      signedAt: json['signed_at'] != null ? DateTime.parse(json['signed_at'] as String) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
      declineReason: json['decline_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'report_id': reportId,
      'envelope_id': envelopeId,
      'signer_email': signerEmail,
      'signer_name': signerName,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      if (sentAt != null) 'sent_at': sentAt!.toIso8601String(),
      if (deliveredAt != null) 'delivered_at': deliveredAt!.toIso8601String(),
      if (signedAt != null) 'signed_at': signedAt!.toIso8601String(),
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      if (declineReason != null) 'decline_reason': declineReason,
    };
  }
}

