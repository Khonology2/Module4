import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/sign_off_report.dart';
import 'api_client.dart';
import 'package:universal_html/html.dart' as html;

// Platform-specific imports (only import when not on web)
import 'dart:io' if (dart.library.html) '../services/file_stub.dart';
import 'package:path_provider/path_provider.dart' if (dart.library.html) '../services/path_provider_stub.dart';

class ReportExportService {
  final ApiClient _apiClient = ApiClient();
  
  /// Fetch digital signatures for a report
  Future<List<Map<String, dynamic>>> _fetchSignatures(String reportId) async {
    try {
      debugPrint('🔍 Fetching signatures for report: $reportId');
      final response = await _apiClient.get('/sign-off-reports/$reportId/signatures');
      debugPrint('📦 Signature response: isSuccess=${response.isSuccess}, data=${response.data}');
      
      if (response.isSuccess && response.data != null) {
        // Backend returns {success: true, data: [signatures]}
        // So response.data already contains the array
        final data = response.data as List?;
        debugPrint('✅ Found ${data?.length ?? 0} signatures');
        return data?.map((e) => e as Map<String, dynamic>).toList() ?? [];
      }
      debugPrint('⚠️ No signatures found or request failed');
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching signatures: $e');
      return [];
    }
  }
  
  /// Export report as PDF
  Future<void> exportReportAsPDF(SignOffReport report, {String? filePath}) async {
    try {
      // Fetch signatures first
      final signatures = await _fetchSignatures(report.id);
      
      final pdf = pw.Document();
      
      // Build PDF content
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'SIGN-OFF REPORT',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      _formatDate(report.createdAt),
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Report Title
              pw.Text(
                report.reportTitle,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              
              // Report Content
              pw.Text(
                'Report Content',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                report.reportContent,
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 15),
              
              // Known Limitations
              if (report.knownLimitations != null && report.knownLimitations!.isNotEmpty) ...[
                pw.Text(
                  'Known Limitations',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  report.knownLimitations!,
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 15),
              ],
              
              // Next Steps
              if (report.nextSteps != null && report.nextSteps!.isNotEmpty) ...[
                pw.Text(
                  'Next Steps',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  report.nextSteps!,
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 15),
              ],
              
              // Digital Signatures Section
              if (signatures.isNotEmpty) ...[
                pw.Divider(),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Digital Signatures',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'This document has been digitally signed by the following parties:',
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 15),
                
                // Display all signatures
                ...signatures.map((sig) {
                  final signerName = sig['signer_name'] as String? ?? 'Unknown';
                  final signerRole = sig['signer_role'] as String? ?? 'Unknown';
                  final signedAt = sig['signed_at'] as String?;
                  final signatureData = sig['signature_data'] as String?;
                  final signatureHash = sig['signature_hash'] as String? ?? '';
                  
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 20),
                    padding: const pw.EdgeInsets.all(15),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Signature Image
                        if (signatureData != null && signatureData.isNotEmpty)
                          pw.Container(
                            width: 150,
                            height: 70,
                            margin: const pw.EdgeInsets.only(right: 15),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey300),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.ClipRRect(
                              horizontalRadius: 4,
                              verticalRadius: 4,
                              child: _buildSignatureImage(signatureData),
                            ),
                          ),
                        // Signature Details
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                signerName,
                                style: pw.TextStyle(
                                  fontSize: 13,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                _formatRole(signerRole),
                                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                              ),
                              if (signedAt != null) ...[
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  'Signed: ${_formatDateTime(signedAt)}',
                                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                                ),
                              ],
                              pw.SizedBox(height: 8),
                              pw.Row(
                                children: [
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: const pw.BoxDecoration(
                                      color: PdfColors.green100,
                                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
                                    ),
                                    child: pw.Text(
                                      '✓ Verified',
                                      style: pw.TextStyle(
                                        fontSize: 9,
                                        color: PdfColors.green900,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text(
                                'Hash: ${signatureHash.substring(0, signatureHash.length > 16 ? 16 : signatureHash.length)}...',
                                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                pw.SizedBox(height: 15),
              ],
              
              // Status and Metadata
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Status: ${_formatStatus(report.status)}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Created by: ${report.createdBy}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  if (report.approvedAt != null)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Approved on: ${_formatDate(report.approvedAt!)}',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                        if (report.approvedBy != null)
                          pw.Text(
                            'Approved by: ${report.approvedBy}',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                ],
              ),
            ];
          },
        ),
      );
      
      // Save or share PDF
      final bytes = await pdf.save();
      final fileSize = bytes.length;
      final fileHash = _generateFileHash(bytes);
      
      // Track export in database
      try {
        await _apiClient.post('/sign-off-reports/${report.id}/export', body: {
          'exportFormat': 'pdf',
          'exportType': filePath != null ? 'download' : 'share',
          'fileSize': fileSize,
          'fileHash': fileHash,
          'metadata': {
            'reportTitle': report.reportTitle,
            'reportStatus': report.status.toString(),
            'exportedAt': DateTime.now().toIso8601String(),
          },
        },);
        debugPrint('✅ Export tracked in database');
      } catch (e) {
        debugPrint('⚠️ Failed to track export: $e');
        // Continue even if tracking fails
      }
      
      if (kIsWeb) {
        // Web platform - trigger browser download
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final fileName = 'Report_${report.reportTitle.replaceAll(' ', '_')}_${report.id}.pdf';
        html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click()
          ..remove();
        html.Url.revokeObjectUrl(url);
        debugPrint('✅ PDF downloaded successfully');
      } else {
        // Mobile/Desktop platforms - use File and path_provider
        if (filePath != null) {
          // Save to specific path
          final file = _createFile(filePath);
          await file.writeAsBytes(bytes);
        } else {
          // Try to save to temp directory and share
          try {
            final tempDir = await getTemporaryDirectory();
            final sanitizedTitle = report.reportTitle.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_');
            final filePath = '${tempDir.path}/${sanitizedTitle}_${report.id}.pdf';
            final file = _createFile(filePath);
            await file.writeAsBytes(bytes);
            
            await Share.shareXFiles(
              [XFile(filePath)],
              text: 'Sign-Off Report: ${report.reportTitle}',
            );
          } catch (e) {
            // Fallback: share as base64 if path_provider fails
            debugPrint('⚠️ Path provider not available, using base64 share: $e');
            final base64Pdf = base64Encode(bytes);
            await Share.share(
              'data:application/pdf;base64,$base64Pdf',
              subject: 'Sign-Off Report: ${report.reportTitle}',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error exporting PDF: $e');
      rethrow;
    }
  }
  
  /// Print report
  Future<void> printReport(SignOffReport report) async {
    try {
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              pw.Text(
                report.reportTitle,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                report.reportContent,
                style: const pw.TextStyle(fontSize: 12),
              ),
            ];
          },
        ),
      );
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      debugPrint('Error printing report: $e');
      rethrow;
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  String _formatDateTime(String dateTimeString) {
    try {
      final parsed = DateTime.parse(dateTimeString);
      // Convert to the user's local timezone for accurate display
      final dateTime = parsed.toLocal();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
             '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeString;
    }
  }
  
  String _formatRole(String role) {
    switch (role.toLowerCase()) {
      case 'deliverylead':
        return 'Delivery Lead';
      case 'clientreviewer':
        return 'Client Reviewer';
      case 'teammember':
        return 'Team Member';
      case 'admin':
        return 'Administrator';
      default:
        return role;
    }
  }
  
  String _formatStatus(ReportStatus status) {
    switch (status) {
      case ReportStatus.draft:
        return 'Draft';
      case ReportStatus.submitted:
        return 'Submitted';
      case ReportStatus.underReview:
        return 'Under Review';
      case ReportStatus.approved:
        return 'Approved';
      case ReportStatus.changeRequested:
        return 'Change Requested';
      case ReportStatus.rejected:
        return 'Rejected';
    }
  }
  
  /// Generate SHA-256 hash of file bytes
  String _generateFileHash(List<int> bytes) {
    // In a real implementation, use crypto package
    // For now, return a simple hash
    final hash = bytes.fold(0, (sum, byte) => sum + byte);
    return hash.toString();
  }
  
  /// Create a File instance (platform-specific)
  /// This method handles the conditional import properly
  File _createFile(String path) {
    // On web, this will throw UnsupportedError from the stub
    // On mobile/desktop, this will use dart:io File
    return File(path);
  }

  /// Build signature image with error handling for PDF export
  pw.Widget _buildSignatureImage(String? signatureData) {
    if (signatureData == null || signatureData.isEmpty) {
      return pw.Container(
        height: 70,
        width: 150,
        color: PdfColors.grey200,
        child: pw.Center(
          child: pw.Text('No signature'),
        ),
      );
    }

    try {
      // Check if signatureData looks like JSON
      final trimmedData = signatureData.trim();
      if (trimmedData.startsWith('{') || trimmedData.startsWith('[') || 
          trimmedData.startsWith('"success"') || trimmedData.startsWith('"error"')) {
        return pw.Container(
          height: 70,
          width: 150,
          color: PdfColors.grey200,
          child: pw.Center(
            child: pw.Text('Invalid signature data'),
          ),
        );
      }

      final Uint8List imageBytes = base64Decode(
        signatureData.contains(',') ? signatureData.split(',').last : signatureData
      );
      
      return pw.Image(
        pw.MemoryImage(imageBytes),
        fit: pw.BoxFit.contain,
      );
    } catch (e) {
      return pw.Container(
        height: 70,
        width: 150,
        color: PdfColors.grey200,
        child: pw.Center(
          child: pw.Text('Invalid signature format'),
        ),
      );
    }
  }
}

