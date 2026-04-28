import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../theme/flownet_theme.dart';

/// Widget to display digital signatures with signer information
/// Shows signature image, signer name, date, and verification status
class SignatureDisplayWidget extends StatelessWidget {
  final String? signatureData; // Base64 encoded signature image
  final String signerName;
  final String signerRole;
  final DateTime signedDate;
  final String title; // e.g., "Delivery Lead Signature", "Client Approval Signature"
  final bool isVerified;
  final String? signatureType; // 'manual', 'docusign', etc.
  
  const SignatureDisplayWidget({
    super.key,
    required this.signatureData,
    required this.signerName,
    required this.signerRole,
    required this.signedDate,
    required this.title,
    this.isVerified = true,
    this.signatureType = 'manual',
  });

  /// Build signature image with error handling
  Widget _buildSignatureImage() {
    if (signatureData == null || signatureData!.isEmpty) {
      return Container(
        height: 120,
        width: double.infinity,
        color: Colors.grey[200],
        child: const Center(
          child: Text('No signature'),
        ),
      );
    }

    try {
      // Check if signatureData looks like JSON (starts with { or [)
      final trimmedData = signatureData!.trim();
      if (trimmedData.startsWith('{') || trimmedData.startsWith('[') || 
          trimmedData.startsWith('"success"') || trimmedData.startsWith('"error"')) {
        return Container(
          height: 120,
          width: double.infinity,
          color: Colors.grey[200],
          child: const Center(
            child: Text('Invalid signature data'),
          ),
        );
      }

      final Uint8List imageBytes = base64Decode(
        signatureData!.contains(',') ? signatureData!.split(',').last : signatureData!
      );
      
      return Image.memory(
        imageBytes,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 120,
            width: double.infinity,
            color: Colors.grey[200],
            child: const Center(
              child: Text('Failed to load signature'),
            ),
          );
        },
      );
    } catch (e) {
      return Container(
        height: 120,
        width: double.infinity,
        color: Colors.grey[200],
        child: const Center(
          child: Text('Invalid signature format'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // If no signature data, show empty state
    if (signatureData == null || signatureData!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlownetColors.graphiteGray,
        border: Border.all(
          color: isVerified ? Colors.green : Colors.orange,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and verification badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: FlownetColors.pureWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isVerified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, color: Colors.green, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Verified',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Signature image
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: FlownetColors.coolGray),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: _buildSignatureImage(),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Signer information
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(
                icon: Icons.person,
                label: 'Signed by:',
                value: signerName,
              ),
              const SizedBox(height: 6),
              _buildInfoRow(
                icon: Icons.badge,
                label: 'Role:',
                value: _formatRole(signerRole),
              ),
              const SizedBox(height: 6),
              _buildInfoRow(
                icon: Icons.calendar_today,
                label: 'Signed on:',
                value: _formatDate(signedDate),
              ),
              if (signatureType != null && signatureType != 'manual') ...[
                const SizedBox(height: 6),
                _buildInfoRow(
                  icon: Icons.security,
                  label: 'Method:',
                  value: _formatSignatureType(signatureType!),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: FlownetColors.coolGray, size: 14),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: FlownetColors.coolGray,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: FlownetColors.pureWhite,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  String _formatRole(String role) {
    switch (role.toLowerCase()) {
      case 'deliverylead':
        return 'Delivery Lead';
      case 'clientreviewer':
        return 'Client Reviewer';
      case 'systemadmin':
        return 'System Admin';
      default:
        return role;
    }
  }

  String _formatDate(DateTime date) {
    final tz = date.toUtc().add(const Duration(hours: 2));
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = tz.hour.toString().padLeft(2, '0');
    final m = tz.minute.toString().padLeft(2, '0');
    return '${tz.day} ${months[tz.month - 1]} ${tz.year} at $h:$m';
  }

  String _formatSignatureType(String type) {
    switch (type.toLowerCase()) {
      case 'docusign':
        return 'DocuSign (Certified)';
      case 'manual':
        return 'Manual Signature';
      case 'eid':
        return 'Electronic ID';
      default:
        return type;
    }
  }
}

/// Compact version for lists
class SignatureDisplayCompact extends StatelessWidget {
  final String signerName;
  final DateTime signedDate;
  final bool isVerified;
  
  const SignatureDisplayCompact({
    super.key,
    required this.signerName,
    required this.signedDate,
    this.isVerified = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        border: Border.all(color: Colors.green),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified ? Icons.verified : Icons.edit,
            color: Colors.green,
            size: 16,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Signed by $signerName',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatCompactDate(signedDate),
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCompactDate(DateTime date) {
    final tz = date.toUtc().add(const Duration(hours: 2));
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${two(tz.day)}/${two(tz.month)}/${tz.year} ${two(tz.hour)}:${two(tz.minute)}';
  }
}

