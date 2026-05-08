import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/sign_off_report.dart';
import '../models/user_signature.dart';
import 'api_client.dart';
import 'package:universal_html/html.dart' as html;
import 'auth_service.dart';
import 'signature_service.dart';

// Platform-specific imports (only import when not on web)
import 'dart:io' if (dart.library.html) '../services/file_stub.dart';
import 'package:path_provider/path_provider.dart' if (dart.library.html) '../services/path_provider_stub.dart';

class _PdfHeaderAssets {
  final pw.ImageProvider? background;
  final pw.ImageProvider? logo;
  final pw.ImageProvider? icon;
  final PdfColor accent;

  const _PdfHeaderAssets({
    required this.background,
    required this.logo,
    required this.icon,
    required this.accent,
  });
}

class _PdfFooterAssets {
  final pw.ImageProvider? logo;

  const _PdfFooterAssets({required this.logo});
}

class _PdfFontAssets {
  final pw.Font base;
  final pw.Font bold;

  const _PdfFontAssets({required this.base, required this.bold});
}

class ReportExportService {
  final ApiClient _apiClient = ApiClient();
  Future<_PdfHeaderAssets>? _headerAssetsFuture;
  Future<_PdfFooterAssets>? _footerAssetsFuture;
  Future<_PdfFontAssets>? _fontAssetsFuture;
  
  /// Fetch digital signatures for a report
  Future<List<Map<String, dynamic>>> _fetchSignatures(String reportId) async {
    try {
      debugPrint('🔍 Fetching signatures for report: $reportId');
      final response = await _apiClient.get('/sign-off-reports/$reportId/signatures');
      debugPrint('📦 Signature response: isSuccess=${response.isSuccess}, data=${response.data}');
      
      if (response.isSuccess && response.data != null) {
        final raw = response.data;
        List<dynamic> items = const [];
        if (raw is List) {
          items = raw;
        } else if (raw is Map) {
          final d = raw['data'];
          if (d is List) {
            items = d;
          } else if (d is Map) {
            final inner = d['items'] ?? d['data'];
            if (inner is List) items = inner;
          }
        }
        debugPrint('✅ Found ${items.length} signatures');
        return items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      debugPrint('⚠️ No signatures found or request failed');
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching signatures: $e');
      return [];
    }
  }

  Future<SignOffReport?> _fetchLatestReport(String reportId) async {
    try {
      final resp = await _apiClient.get('/sign-off-reports/$reportId');
      if (!resp.isSuccess || resp.data == null) return null;
      final raw = resp.data;
      if (raw is Map) {
        final Map<String, dynamic> body = Map<String, dynamic>.from(raw);
        final dynamic inner = body['data'] ?? body['report'] ?? body;
        if (inner is Map) {
          return SignOffReport.fromJson(Map<String, dynamic>.from(inner));
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
  
  /// Export report as PDF
  Future<void> exportReportAsPDF(SignOffReport report, {String? filePath}) async {
    try {
      // Fetch signatures first
      final signatures = await _fetchSignatures(report.id);
      final latestReport = await _fetchLatestReport(report.id);
      final effectiveReport = latestReport ?? report;
      final header = await _getHeaderAssets();
      final footer = await _getFooterAssets();
      final fonts = await _getFontAssets();
      final currentUser = await AuthService().getCurrentUser();
      UserSignature? defaultSignature;
      try {
        defaultSignature = await SignatureService(_apiClient).getDefaultSignature();
      } catch (_) {}

      if (effectiveReport.sprintIds.isNotEmpty) {
        final sprintReport = await _fetchSprintReport(effectiveReport.sprintIds.first);
        if (sprintReport != null) {
          final pdf = _buildSprintSignOffPdf(
            report: effectiveReport,
            sprintReport: sprintReport,
            signatures: signatures,
            header: header,
            footer: footer,
            fonts: fonts,
          );

          final bytes = await pdf.save();
          final fileSize = bytes.length;
          final fileHash = _generateFileHash(bytes);

          try {
            await _apiClient.post(
              '/sign-off-reports/${effectiveReport.id}/export',
              body: {
                'exportFormat': 'pdf',
                'exportType': filePath != null ? 'download' : 'share',
                'fileSize': fileSize,
                'fileHash': fileHash,
                'metadata': {
                  'reportTitle': effectiveReport.reportTitle,
                  'reportStatus': effectiveReport.status.toString(),
                  'exportedAt': DateTime.now().toIso8601String(),
                  'template': 'sprint_signoff_v1',
                  'sprintId': effectiveReport.sprintIds.first,
                },
              },
            );
          } catch (_) {}

          if (kIsWeb) {
            final blob = html.Blob([bytes], 'application/pdf');
            final url = html.Url.createObjectUrlFromBlob(blob);
            final fileName =
                'Sprint_Signoff_${effectiveReport.reportTitle.replaceAll(' ', '_')}_${effectiveReport.id}.pdf';
            html.AnchorElement(href: url)
              ..setAttribute('download', fileName)
              ..click()
              ..remove();
            html.Url.revokeObjectUrl(url);
            return;
          }

          if (filePath != null) {
            final file = _createFile(filePath);
            await file.writeAsBytes(bytes);
            return;
          }

          try {
            final tempDir = await getTemporaryDirectory();
            final sanitizedTitle =
                effectiveReport.reportTitle.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_');
            final outPath = '${tempDir.path}/${sanitizedTitle}_${effectiveReport.id}.pdf';
            final file = _createFile(outPath);
            await file.writeAsBytes(bytes);
            await Share.shareXFiles([XFile(outPath)],
                text: 'Sprint Sign-Off Report: ${effectiveReport.reportTitle}');
            return;
          } catch (e) {
            final base64Pdf = base64Encode(bytes);
            await Share.share(
              'data:application/pdf;base64,$base64Pdf',
              subject: 'Sprint Sign-Off Report: ${effectiveReport.reportTitle}',
            );
            return;
          }
        }
      }

      final sanitizedContent = SignOffReport.sanitizeReportContent(effectiveReport.reportContent);
      final reportBodyContent = _stripSignOffNotesFromBody(_stripFeedbackFromBody(sanitizedContent));
      var preparedSigData = _pickPreparedBySignatureData(report: effectiveReport, signatures: signatures);
      var preparedSigType = _pickPreparedBySignatureType(report: effectiveReport, signatures: signatures);
      if ((preparedSigData == null || preparedSigData.trim().isEmpty) && defaultSignature != null) {
        final data = defaultSignature.signatureData.trim();
        if (data.isNotEmpty && currentUser != null) {
          final uid = currentUser.id.trim();
          final uname = currentUser.name.trim().toLowerCase();
          final uemail = currentUser.email.trim().toLowerCase();
          final reportPreparedId = (effectiveReport.preparedBy ?? '').trim();
          final reportCreatedId = effectiveReport.createdBy.trim();
          final reportPreparedName = (effectiveReport.preparedByName ?? '').trim().toLowerCase();
          final createdLower = reportCreatedId.toLowerCase();
          final preparedLower = reportPreparedId.toLowerCase();
          if ((uid.isNotEmpty && (uid == reportPreparedId || uid == reportCreatedId)) ||
              (uemail.isNotEmpty && (uemail == createdLower || uemail == preparedLower)) ||
              (uname.isNotEmpty && uname == reportPreparedName)) {
            preparedSigData = data;
            preparedSigType = defaultSignature.signatureType;
          }
        }
      }
      
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: fonts.base, bold: fonts.bold),
      );
      
      // Build PDF content
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          header: (context) => context.pageNumber == 1
              ? _buildSignOffReportHeader(
                  header: header,
                  reportTypeLabel: 'SIGN-OFF REPORT',
                  reportTitle: effectiveReport.reportTitle,
                  date: effectiveReport.createdAt,
                )
              : pw.SizedBox(height: 0),
          footer: (context) => _buildSignOffReportFooter(
            footer: footer,
            statusText: _formatStatus(effectiveReport.status),
            createdByText: effectiveReport.preparedByName ?? effectiveReport.createdBy,
          ),
          build: (pw.Context context) {
            final signOffNotesText = _buildSignOffNotesText(
              reportContent: sanitizedContent,
              clientComment: effectiveReport.clientComment,
              changeRequestDetails: effectiveReport.changeRequestDetails,
              status: effectiveReport.status,
            );
            final reviewerSigData = _pickReviewerSignatureData(report: effectiveReport, signatures: signatures);
            final reviewerSigType = _pickReviewerSignatureType(report: effectiveReport, signatures: signatures);
            final reviewerName = (effectiveReport.status == ReportStatus.approved
                    ? (effectiveReport.approvedByName ??
                        effectiveReport.reviewedByName ??
                        effectiveReport.approvedBy ??
                        effectiveReport.reviewedBy)
                    : (effectiveReport.reviewedByName ??
                        effectiveReport.approvedByName ??
                        effectiveReport.reviewedBy ??
                        effectiveReport.approvedBy))
                ?.trim();
            final reviewerRole = (effectiveReport.status == ReportStatus.approved
                    ? (effectiveReport.approvedByRole ?? effectiveReport.reviewedByRole)
                    : (effectiveReport.reviewedByRole ?? effectiveReport.approvedByRole))
                ?.trim();
            final reviewerSignedAt = effectiveReport.status == ReportStatus.approved
                ? (effectiveReport.approvedAt ?? effectiveReport.reviewedAt)
                : (effectiveReport.reviewedAt ?? effectiveReport.approvedAt);
            final reviewerLabel = effectiveReport.status == ReportStatus.approved
                ? 'APPROVED BY'
                : (effectiveReport.status == ReportStatus.changeRequested
                    ? 'CHANGES REQUESTED BY'
                    : 'REVIEWED BY');
            return [
              pw.SizedBox(height: 6),
              ..._buildStructuredBodyWidgets(reportBodyContent),
              if (effectiveReport.knownLimitations != null && effectiveReport.knownLimitations!.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                _subSectionHeader('KNOWN LIMITATIONS'),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: pw.Text(effectiveReport.knownLimitations!, style: const pw.TextStyle(fontSize: 10)),
                ),
              ],
              
              if (effectiveReport.nextSteps != null && effectiveReport.nextSteps!.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                _subSectionHeader('NEXT STEPS'),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: pw.Text(effectiveReport.nextSteps!, style: const pw.TextStyle(fontSize: 10)),
                ),
              ],

              pw.SizedBox(height: 8),
              pw.NewPage(),
              ..._buildKeepHeaderWithFirstParagraphSection(
                title: 'SIGN-OFF NOTES',
                text: signOffNotesText,
                fontSize: 10,
              ),
              pw.SizedBox(height: 8),
              _buildPreparedBySignatureSection(
                preparedByName: effectiveReport.preparedByName ?? effectiveReport.createdBy,
                preparedByRole: effectiveReport.preparedByRole,
                signedAt: effectiveReport.createdAt,
                signatureData: preparedSigData,
                signatureType: preparedSigType,
              ),
              if ((reviewerSigData ?? '').trim().isNotEmpty ||
                  (reviewerName ?? '').trim().isNotEmpty ||
                  effectiveReport.reviewedAt != null ||
                  effectiveReport.approvedAt != null ||
                  effectiveReport.status == ReportStatus.approved ||
                  effectiveReport.status == ReportStatus.changeRequested ||
                  effectiveReport.status == ReportStatus.underReview) ...[
                pw.SizedBox(height: 8),
                _buildReviewedBySignatureSection(
                  label: reviewerLabel,
                  reviewerName: (reviewerName ?? '').trim().isEmpty ? '-' : reviewerName!.trim(),
                  reviewerRole: reviewerRole,
                  signedAt: reviewerSignedAt,
                  signatureData: reviewerSigData,
                  signatureType: reviewerSigType,
                ),
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
                        'Status: ${_formatStatus(effectiveReport.status)}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Created by: ${effectiveReport.createdBy}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  if (effectiveReport.approvedAt != null)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Approved on: ${_formatDate(effectiveReport.approvedAt!)}',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                        if (effectiveReport.approvedBy != null)
                          pw.Text(
                            'Approved by: ${effectiveReport.approvedBy}',
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
        await _apiClient.post('/sign-off-reports/${effectiveReport.id}/export', body: {
          'exportFormat': 'pdf',
          'exportType': filePath != null ? 'download' : 'share',
          'fileSize': fileSize,
          'fileHash': fileHash,
          'metadata': {
            'reportTitle': effectiveReport.reportTitle,
            'reportStatus': effectiveReport.status.toString(),
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
        final fileName =
            'Report_${effectiveReport.reportTitle.replaceAll(' ', '_')}_${effectiveReport.id}.pdf';
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
            final sanitizedTitle =
                effectiveReport.reportTitle.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_');
            final filePath = '${tempDir.path}/${sanitizedTitle}_${effectiveReport.id}.pdf';
            final file = _createFile(filePath);
            await file.writeAsBytes(bytes);
            
            await Share.shareXFiles(
              [XFile(filePath)],
              text: 'Sign-Off Report: ${effectiveReport.reportTitle}',
            );
          } catch (e) {
            // Fallback: share as base64 if path_provider fails
            debugPrint('⚠️ Path provider not available, using base64 share: $e');
            final base64Pdf = base64Encode(bytes);
            await Share.share(
              'data:application/pdf;base64,$base64Pdf',
              subject: 'Sign-Off Report: ${effectiveReport.reportTitle}',
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
      final signatures = await _fetchSignatures(report.id);
      final latestReport = await _fetchLatestReport(report.id);
      final effectiveReport = latestReport ?? report;
      final header = await _getHeaderAssets();
      final footer = await _getFooterAssets();
      final fonts = await _getFontAssets();
      final currentUser = await AuthService().getCurrentUser();
      UserSignature? defaultSignature;
      try {
        defaultSignature = await SignatureService(_apiClient).getDefaultSignature();
      } catch (_) {}

      if (effectiveReport.sprintIds.isNotEmpty) {
        final sprintReport = await _fetchSprintReport(effectiveReport.sprintIds.first);
        if (sprintReport != null) {
          final sprintPdf = _buildSprintSignOffPdf(
            report: effectiveReport,
            sprintReport: sprintReport,
            signatures: signatures,
            header: header,
            footer: footer,
            fonts: fonts,
          );
          await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => sprintPdf.save(),
          );
          return;
        }
      }

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: fonts.base, bold: fonts.bold),
      );
      final sanitizedContent = SignOffReport.sanitizeReportContent(effectiveReport.reportContent);
      final reportBodyContent = _stripSignOffNotesFromBody(_stripFeedbackFromBody(sanitizedContent));
      var preparedSigData = _pickPreparedBySignatureData(report: effectiveReport, signatures: signatures);
      var preparedSigType = _pickPreparedBySignatureType(report: effectiveReport, signatures: signatures);
      if ((preparedSigData == null || preparedSigData.trim().isEmpty) && defaultSignature != null) {
        final data = defaultSignature.signatureData.trim();
        if (data.isNotEmpty && currentUser != null) {
          final uid = currentUser.id.trim();
          final uname = currentUser.name.trim().toLowerCase();
          final uemail = currentUser.email.trim().toLowerCase();
          final reportPreparedId = (effectiveReport.preparedBy ?? '').trim();
          final reportCreatedId = effectiveReport.createdBy.trim();
          final reportPreparedName = (effectiveReport.preparedByName ?? '').trim().toLowerCase();
          final createdLower = reportCreatedId.toLowerCase();
          final preparedLower = reportPreparedId.toLowerCase();
          if ((uid.isNotEmpty && (uid == reportPreparedId || uid == reportCreatedId)) ||
              (uemail.isNotEmpty && (uemail == createdLower || uemail == preparedLower)) ||
              (uname.isNotEmpty && uname == reportPreparedName)) {
            preparedSigData = data;
            preparedSigType = defaultSignature.signatureType;
          }
        }
      }
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          header: (context) => context.pageNumber == 1
              ? _buildSignOffReportHeader(
                  header: header,
                  reportTypeLabel: effectiveReport.sprintIds.isNotEmpty ? 'SPRINT SIGN-OFF REPORT' : 'SIGN-OFF REPORT',
                  reportTitle: effectiveReport.reportTitle,
                  date: effectiveReport.createdAt,
                )
              : pw.SizedBox(height: 0),
          footer: (context) => _buildSignOffReportFooter(
            footer: footer,
            statusText: _formatStatus(effectiveReport.status),
            createdByText: effectiveReport.preparedByName ?? effectiveReport.createdBy,
          ),
          build: (pw.Context context) {
            final signOffNotesText = _buildSignOffNotesText(
              reportContent: sanitizedContent,
              clientComment: effectiveReport.clientComment,
              changeRequestDetails: effectiveReport.changeRequestDetails,
              status: effectiveReport.status,
            );
            final reviewerSigData = _pickReviewerSignatureData(report: effectiveReport, signatures: signatures);
            final reviewerSigType = _pickReviewerSignatureType(report: effectiveReport, signatures: signatures);
            final reviewerName = (effectiveReport.status == ReportStatus.approved
                    ? (effectiveReport.approvedByName ??
                        effectiveReport.reviewedByName ??
                        effectiveReport.approvedBy ??
                        effectiveReport.reviewedBy)
                    : (effectiveReport.reviewedByName ??
                        effectiveReport.approvedByName ??
                        effectiveReport.reviewedBy ??
                        effectiveReport.approvedBy))
                ?.trim();
            final reviewerRole = (effectiveReport.status == ReportStatus.approved
                    ? (effectiveReport.approvedByRole ?? effectiveReport.reviewedByRole)
                    : (effectiveReport.reviewedByRole ?? effectiveReport.approvedByRole))
                ?.trim();
            final reviewerSignedAt = effectiveReport.status == ReportStatus.approved
                ? (effectiveReport.approvedAt ?? effectiveReport.reviewedAt)
                : (effectiveReport.reviewedAt ?? effectiveReport.approvedAt);
            final reviewerLabel = effectiveReport.status == ReportStatus.approved
                ? 'APPROVED BY'
                : (effectiveReport.status == ReportStatus.changeRequested ? 'CHANGES REQUESTED BY' : 'REVIEWED BY');
            return [
              pw.SizedBox(height: 6),
              ..._buildStructuredBodyWidgets(reportBodyContent),
              pw.SizedBox(height: 8),
              pw.NewPage(),
              ..._buildKeepHeaderWithFirstParagraphSection(
                title: 'SIGN-OFF NOTES',
                text: signOffNotesText,
                fontSize: 10,
              ),

              pw.SizedBox(height: 8),
              _buildPreparedBySignatureSection(
                preparedByName: effectiveReport.preparedByName ?? effectiveReport.createdBy,
                preparedByRole: effectiveReport.preparedByRole,
                signedAt: effectiveReport.createdAt,
                signatureData: preparedSigData,
                signatureType: preparedSigType,
              ),

              if ((reviewerSigData ?? '').trim().isNotEmpty ||
                  (reviewerName ?? '').trim().isNotEmpty ||
                  effectiveReport.reviewedAt != null ||
                  effectiveReport.approvedAt != null ||
                  effectiveReport.status == ReportStatus.approved ||
                  effectiveReport.status == ReportStatus.changeRequested ||
                  effectiveReport.status == ReportStatus.underReview) ...[
                pw.SizedBox(height: 8),
                _buildReviewedBySignatureSection(
                  label: reviewerLabel,
                  reviewerName: (reviewerName ?? '').trim().isEmpty ? '-' : reviewerName!.trim(),
                  reviewerRole: reviewerRole,
                  signedAt: reviewerSignedAt,
                  signatureData: reviewerSigData,
                  signatureType: reviewerSigType,
                ),
              ],
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

  Future<void> exportTextAsPDF({
    required String title,
    required String content,
    bool useSignOffTemplate = false,
    String? subtitle,
    String? preparedBySignatureData,
    String? preparedBySignatureType,
    String? preparedByNameOverride,
    String? preparedByRoleOverride,
  }) async {
    final fonts = await _getFontAssets();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: fonts.base, bold: fonts.bold),
    );
    final now = DateTime.now();
    final safeTitle = title.trim().isEmpty ? 'Report' : title.trim();

    if (useSignOffTemplate) {
      final header = await _getHeaderAssets();
      final footer = await _getFooterAssets();
      String preparedByName = (preparedByNameOverride ?? '').trim();
      String? preparedByRole = (preparedByRoleOverride ?? '').trim().isEmpty ? null : preparedByRoleOverride!.trim();
      String? signatureData = (preparedBySignatureData ?? '').trim().isEmpty ? null : preparedBySignatureData!.trim();
      String signatureType = (preparedBySignatureType ?? '').trim().isEmpty ? 'manual' : preparedBySignatureType!.trim();
      DateTime signedAt = now;

      try {
        final user = await AuthService().getCurrentUser();
        if (user != null) {
          if (preparedByName.isEmpty) {
            preparedByName = user.name.isNotEmpty ? user.name : user.email;
          }
          preparedByRole ??= user.roleDisplayName;
        }
      } catch (_) {}

      if (signatureData == null || signatureData.trim().isEmpty) {
        try {
          final sigs = await SignatureService(_apiClient).getUserSignatures();
          final active = sigs.where((s) => s.isActive).toList();
          UserSignature? pick;
          for (final s in active) {
            if (s.isDefault) {
              pick = s;
              break;
            }
          }
          pick ??= active.isNotEmpty ? active.first : null;
          if (pick != null) {
            signatureData = pick.signatureData;
            signatureType = pick.signatureType;
            signedAt = pick.lastUsedAt ?? now;
            if (preparedByName.trim().isEmpty && (pick.userName ?? '').trim().isNotEmpty) {
              preparedByName = pick.userName!.trim();
            }
          }
        } catch (_) {}
      }

      const reportTypeLabel = 'SPRINT SIGN-OFF REPORT';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          header: (context) => context.pageNumber == 1
              ? _buildSignOffReportHeader(
                  header: header,
                  reportTypeLabel: reportTypeLabel,
                  reportTitle: safeTitle,
                  date: now,
                )
              : pw.SizedBox(height: 0),
          footer: (context) => _buildSignOffReportFooter(
            footer: footer,
            statusText: null,
            createdByText: null,
          ),
          build: (pw.Context context) {
            final reportBodyContent = _stripSignOffNotesFromBody(_stripFeedbackFromBody(content));
            final signOffNotesText = _buildSignOffNotesText(
              reportContent: content,
              clientComment: null,
              changeRequestDetails: null,
              status: ReportStatus.draft,
            );
            return [
              pw.SizedBox(height: 6),
              ..._buildStructuredBodyWidgets(reportBodyContent),
              pw.SizedBox(height: 8),
              pw.NewPage(),
              ..._buildKeepHeaderWithFirstParagraphSection(
                title: 'SIGN-OFF NOTES',
                text: signOffNotesText,
                fontSize: 10,
              ),

              pw.SizedBox(height: 8),
              _buildPreparedBySignatureSection(
                preparedByName: preparedByName.isEmpty ? '-' : preparedByName,
                preparedByRole: preparedByRole,
                signedAt: signedAt,
                signatureData: signatureData,
                signatureType: signatureType,
              ),
            ];
          },
        ),
      );
    } else {
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  safeTitle,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  _formatDate(now),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              content,
              style: const pw.TextStyle(fontSize: 11),
            ),
          ];
        },
      ),
    );
    }

    final bytes = await pdf.save();
    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final fileName = '${safeTitle.replaceAll(RegExp(r"[^\w\s-]"), "").replaceAll(RegExp(r"\s+"), "_")}_${now.toIso8601String().replaceAll(":", "-")}.pdf';
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click()
        ..remove();
      html.Url.revokeObjectUrl(url);
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/${safeTitle.replaceAll(RegExp(r"[^\w\s-]"), "").replaceAll(RegExp(r"\s+"), "_")}_${now.toIso8601String().replaceAll(":", "-")}.pdf';
      final file = _createFile(filePath);
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(filePath)], text: safeTitle);
    } catch (_) {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
      );
    }
  }

  Future<_PdfHeaderAssets> _getHeaderAssets() {
    _headerAssetsFuture ??= _loadHeaderAssets();
    return _headerAssetsFuture!;
  }

  Future<_PdfHeaderAssets> _loadHeaderAssets() async {
    try {
      final bgData = await rootBundle.load('assets/images/khono_bg.png');
      final logoData = await rootBundle.load('assets/Icons/khono.png');
      final iconData = await rootBundle.load('assets/Icons/Group 268.png');
      final bgBytes = bgData.buffer.asUint8List();
      final logoBytes = logoData.buffer.asUint8List();
      final iconBytes = iconData.buffer.asUint8List();
      const accent = PdfColor.fromInt(0xFFC00000);
      return _PdfHeaderAssets(
        background: pw.MemoryImage(bgBytes),
        logo: pw.MemoryImage(logoBytes),
        icon: pw.MemoryImage(iconBytes),
        accent: accent,
      );
    } catch (_) {
      return const _PdfHeaderAssets(
        background: null,
        logo: null,
        icon: null,
        accent: PdfColor.fromInt(0xFFE53935),
      );
    }
  }

  Future<_PdfFooterAssets> _getFooterAssets() {
    _footerAssetsFuture ??= _loadFooterAssets();
    return _footerAssetsFuture!;
  }

  Future<_PdfFooterAssets> _loadFooterAssets() async {
    try {
      final logoData = await rootBundle.load('assets/Icons/Red_Khono_Discs.png');
      final logoBytes = logoData.buffer.asUint8List();
      return _PdfFooterAssets(logo: pw.MemoryImage(logoBytes));
    } catch (_) {
      return const _PdfFooterAssets(logo: null);
    }
  }

  Future<_PdfFontAssets> _getFontAssets() {
    _fontAssetsFuture ??= _loadFontAssets();
    return _fontAssetsFuture!;
  }

  Future<_PdfFontAssets> _loadFontAssets() async {
    final regular = await rootBundle.load('assets/fonts/poppins/Poppins-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/poppins/Poppins-Bold.ttf');
    return _PdfFontAssets(
      base: pw.Font.ttf(regular),
      bold: pw.Font.ttf(bold),
    );
  }

  pw.Widget _buildSignOffReportHeader({
    required _PdfHeaderAssets header,
    required String reportTypeLabel,
    required String reportTitle,
    required DateTime date,
  }) {
    final accent = header.accent;
    final bg = header.background;
    final logo = header.logo;
    final icon = header.icon;
    final ribbonText = _sanitizeRibbonTitle(reportTitle);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          height: 84,
          decoration: const pw.BoxDecoration(color: PdfColors.white),
          child: pw.Stack(
            children: [
              if (bg != null)
                pw.Positioned.fill(
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      image: pw.DecorationImage(
                        image: bg,
                        fit: pw.BoxFit.cover,
                        alignment: pw.Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (logo != null) pw.Image(logo, height: 24),
                        if (logo == null)
                          pw.Text(
                            'KHONOLOGY',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 3,
                            ),
                          ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          reportTypeLabel.toUpperCase(),
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        icon == null
                            ? pw.SizedBox(width: 46, height: 46)
                            : pw.Image(icon, width: 46, height: 46, fit: pw.BoxFit.contain),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.Container(
          height: 26,
          decoration: pw.BoxDecoration(color: accent),
          padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  'Title: $ribbonText',
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Text(
                'Date: ${_formatDate(date)}',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSignOffReportFooter({
    required _PdfFooterAssets footer,
    required String? statusText,
    required String? createdByText,
  }) {
    final logo = footer.logo;
    final status = (statusText ?? '').trim();
    final createdBy = (createdByText ?? '').trim();

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.SizedBox(width: 1),
          pw.Expanded(
            child: pw.Center(
              child: logo == null ? pw.SizedBox(height: 20) : pw.Image(logo, height: 20, fit: pw.BoxFit.contain),
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (status.isNotEmpty)
                pw.Text(
                  'Status: $status',
                  style: pw.TextStyle(color: PdfColors.grey700, fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
              if (createdBy.isNotEmpty)
                pw.Text(
                  'Created by: $createdBy',
                  style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchSprintReport(String sprintId) async {
    try {
      final response = await _apiClient.get('/sprints/$sprintId/report');
      if (!response.isSuccess) return null;
      final data = response.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    } catch (_) {
      return null;
    }
  }

  pw.Document _buildSprintSignOffPdf({
    required SignOffReport report,
    required Map<String, dynamic> sprintReport,
    required List<Map<String, dynamic>> signatures,
    required _PdfHeaderAssets header,
    required _PdfFooterAssets footer,
    required _PdfFontAssets fonts,
  }) {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: fonts.base, bold: fonts.bold),
    );

    final sections = _parseReportSections(report.reportContent);
    final projectKv = _parseKeyValues(sections['PROJECT']);
    final totalsKv = _parseKeyValues(sections['PROJECT SPRINT TOTALS']);
    final sprintKv = _parseKeyValues(sections['SPRINT']);
    final summaryKv = _parseKeyValues(sections['SPRINT SUMMARY']);

    final teamLines = (sections['TEAM MEMBERS'] ?? const <String>[]).where((l) => l.trim().isNotEmpty).toList();
    final deliverableLines = (sections['DELIVERABLES'] ?? const <String>[]).where((l) => l.trim().isNotEmpty).toList();
    final signOffLines = (sections['SIGN-OFF NOTES'] ?? const <String>[]).where((l) => l.trim().isNotEmpty).toList();
    final signOffTextFromSection = signOffLines.join('\n').trim();

    final sprintName = (sprintKv['Name'] ?? sprintKv['NAME'] ?? '').trim();
    final resolvedTitle = _resolveRibbonTitle(
      reportTitle: report.reportTitle,
      reportContent: report.reportContent,
      signOffText: signOffTextFromSection,
      clientComment: report.clientComment,
    );
    final ribbonTitle = resolvedTitle.isEmpty ? (sprintName.isEmpty ? '-' : sprintName) : resolvedTitle;

    pw.Widget kvRow(String k, String v) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(text: '${k.trim()}: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
              pw.TextSpan(text: v.trim().isEmpty ? '-' : v.trim(), style: const pw.TextStyle(fontSize: 9, color: PdfColors.black)),
            ],
          ),
        ),
      );
    }

    pw.Widget cell(String title, List<pw.Widget> children) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _subSectionHeader(title),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children),
          ),
        ],
      );
    }

    pw.Widget section(String title, pw.Widget child) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _subSectionHeader(title),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: child,
          ),
        ],
      );
    }

    final signOffText = _buildSignOffNotesText(
      reportContent: report.reportContent,
      clientComment: report.clientComment,
      changeRequestDetails: report.changeRequestDetails,
      status: report.status,
    );

    pw.Widget twoCol(pw.Widget left, pw.Widget right) {
      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        columnWidths: const {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(1)},
        children: [
          pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.all(0), child: left),
            pw.Padding(padding: const pw.EdgeInsets.all(0), child: right),
          ]),
        ],
      );
    }

    pw.Widget signaturesBlock() {
      final preparedByName = report.preparedByName ?? report.createdBy;
      final preparedByRole = report.preparedByRole;
      final preparedSigData = _pickPreparedBySignatureData(report: report, signatures: signatures);
      final preparedSigType = _pickPreparedBySignatureType(report: report, signatures: signatures);
      final reviewerSigData = _pickReviewerSignatureData(report: report, signatures: signatures);
      final reviewerSigType = _pickReviewerSignatureType(report: report, signatures: signatures);
      final reviewerName = (report.status == ReportStatus.approved
              ? (report.approvedByName ?? report.reviewedByName ?? report.approvedBy ?? report.reviewedBy)
              : (report.reviewedByName ?? report.approvedByName ?? report.reviewedBy ?? report.approvedBy))
          ?.trim();
      final reviewerRole = (report.status == ReportStatus.approved
              ? (report.approvedByRole ?? report.reviewedByRole)
              : (report.reviewedByRole ?? report.approvedByRole))
          ?.trim();
      final reviewerSignedAt = report.status == ReportStatus.approved
          ? (report.approvedAt ?? report.reviewedAt)
          : (report.reviewedAt ?? report.approvedAt);
      final reviewerLabel = report.status == ReportStatus.approved
          ? 'APPROVED BY'
          : (report.status == ReportStatus.changeRequested ? 'CHANGES REQUESTED BY' : 'REVIEWED BY');

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _buildPreparedBySignatureSection(
            preparedByName: preparedByName,
            preparedByRole: preparedByRole,
            signedAt: report.createdAt,
            signatureData: preparedSigData,
            signatureType: preparedSigType,
          ),
          if ((reviewerSigData ?? '').trim().isNotEmpty ||
              (reviewerName ?? '').trim().isNotEmpty ||
              report.reviewedAt != null ||
              report.approvedAt != null ||
              report.status == ReportStatus.approved ||
              report.status == ReportStatus.changeRequested ||
              report.status == ReportStatus.underReview) ...[
            pw.SizedBox(height: 8),
            _buildReviewedBySignatureSection(
              label: reviewerLabel,
              reviewerName: (reviewerName ?? '').trim().isEmpty ? '-' : reviewerName!.trim(),
              reviewerRole: reviewerRole,
              signedAt: reviewerSignedAt,
              signatureData: reviewerSigData,
              signatureType: reviewerSigType,
            ),
          ],
        ],
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (context) => context.pageNumber == 1
            ? _buildSignOffReportHeader(
                header: header,
                reportTypeLabel: 'SPRINT SIGN-OFF REPORT',
                reportTitle: ribbonTitle,
                date: report.createdAt,
              )
            : pw.SizedBox(height: 0),
        footer: (context) => _buildSignOffReportFooter(
          footer: footer,
          statusText: _formatStatus(report.status),
          createdByText: report.preparedByName ?? report.createdBy,
        ),
        build: (context) {
          return [
            pw.SizedBox(height: 6),
            twoCol(
              cell('Project Detail', [
                kvRow('Name', projectKv['Name'] ?? projectKv['NAME'] ?? '-'),
                kvRow('Key', projectKv['Key'] ?? projectKv['KEY'] ?? '-'),
                kvRow('ID', projectKv['ID'] ?? projectKv['Id'] ?? '-'),
              ]),
              cell('Project Sprint Totals', [
                kvRow('Total Sprints', totalsKv['Total Sprints'] ?? totalsKv['Total'] ?? '-'),
                kvRow('Completed Sprints', totalsKv['Completed Sprints'] ?? '-'),
                kvRow('Sprint Success Rate', totalsKv['Sprint Success Rate'] ?? '-'),
              ]),
            ),
            pw.SizedBox(height: 8),
            twoCol(
              cell('Sprint Detail', [
                kvRow('Name', sprintKv['Name'] ?? '-'),
                kvRow('ID', sprintKv['ID'] ?? sprintKv['Id'] ?? '-'),
                kvRow('Status', sprintKv['Status'] ?? '-'),
                kvRow('Start', sprintKv['Start'] ?? '-'),
                kvRow('End', sprintKv['End'] ?? '-'),
              ]),
              cell('Sprint Summary', [
                kvRow('Total Deliverables', summaryKv['Total Deliverables'] ?? '-'),
                kvRow('Completed', summaryKv['Completed'] ?? '-'),
                kvRow('In Progress', summaryKv['In Progress'] ?? '-'),
                kvRow('Not Started', summaryKv['Not Started'] ?? summaryKv['Not Started'] ?? '-'),
                kvRow('Overdue', summaryKv['Overdue'] ?? '-'),
                kvRow('Blocked', summaryKv['Blocked'] ?? '-'),
                kvRow('Sprint Progress', summaryKv['Sprint Progress'] ?? '-'),
                kvRow('Completion Rate', summaryKv['Completion Rate'] ?? '-'),
                kvRow('Health', (summaryKv['Health'] ?? '-').toUpperCase()),
              ]),
            ),
            pw.SizedBox(height: 8),
            section(
              'TEAM MEMBERS',
              pw.Text(
                teamLines.isEmpty ? '-' : teamLines.join('\n'),
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
            pw.SizedBox(height: 8),
            section(
              'DELIVERABLES',
              pw.Text(
                deliverableLines.isEmpty ? '-' : deliverableLines.join('\n'),
                style: const pw.TextStyle(fontSize: 8.5),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.NewPage(),
            section(
              'SIGN-OFF NOTES',
              pw.Text(signOffText.trim().isEmpty ? '-' : signOffText, style: const pw.TextStyle(fontSize: 9)),
            ),
            pw.SizedBox(height: 8),
            signaturesBlock(),
          ];
        },
      ),
    );

    return pdf;
  }

  pw.Widget _subSectionHeader(String title) {
    const fill = PdfColor.fromInt(0xFFF2CCCC);
    return pw.Container(
      width: double.infinity,
      height: 22,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const pw.BoxDecoration(
        color: fill,
      ),
      child: pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
      ),
    );
  }

  String _stripFeedbackLabelPrefixes(String text) {
    final raw = text.trim();
    if (raw.isEmpty) return '';
    final out = <String>[];
    for (final line in raw.split('\n')) {
      var t = line.trim();
      if (t.isEmpty) continue;
      t = t.replaceFirst(RegExp(r'^[-•*]+\s*'), '');
      if (t.isEmpty) continue;
      final upper = t.toUpperCase();
      if (upper == 'USER FEEDBACK' || upper == 'CLIENT FEEDBACK' || upper == 'FEEDBACK') continue;
      t = t.replaceFirst(
        RegExp(r'^(user|client)?\s*feedback(\s*[:\\-–—]\\s*|\\s+)', caseSensitive: false),
        '',
      );
      t = t.replaceFirst(RegExp(r'^feedback(\s*[:\\-–—]\\s*|\\s+)', caseSensitive: false), '');
      if (t.trim().isNotEmpty) out.add(t.trim());
    }
    return out.join('\n').trim();
  }

  String _mergeNotesAndComment(String note, String comment) {
    final a = _stripFeedbackLabelPrefixes(note);
    final b = _stripFeedbackLabelPrefixes(comment);
    if (a.isEmpty && b.isEmpty) return '-';
    if (a.isNotEmpty && b.isEmpty) return a;
    if (a.isEmpty && b.isNotEmpty) return b;
    if (a.toLowerCase().contains(b.toLowerCase())) return a;
    return '$a\n\n$b';
  }

  String _extractSignOffNote(String reportContent) {
    final raw = reportContent;
    final lines = raw.split('\n');
    final startIdx = lines.indexWhere((l) => l.trim().toUpperCase() == 'SIGN-OFF NOTES');
    if (startIdx == -1) return '';
    final buf = <String>[];
    for (var i = startIdx + 1; i < lines.length; i++) {
      final t = lines[i].trim();
      if (t.isEmpty) continue;
      if (t.toUpperCase() == 'DELIVERABLES') break;
      buf.add(t);
    }
    return _stripFeedbackLabelPrefixes(buf.join('\n')).replaceAll('\n', ' ').trim();
  }

  String _buildSignOffNotesText({
    required String reportContent,
    required String? clientComment,
    required String? changeRequestDetails,
    required ReportStatus status,
  }) {
    final note = _extractSignOffNote(reportContent);
    final comment = (clientComment ?? '').trim();
    final changes = (changeRequestDetails ?? '').trim();

    var merged = note;

    if (status == ReportStatus.approved) {
      final c = _stripFeedbackLabelPrefixes(comment);
      if (c.isNotEmpty) {
        merged = _mergeNotesAndComment(merged, 'Approval comment:\n$c');
      }
    } else if (status == ReportStatus.changeRequested) {
      final cr = _stripFeedbackLabelPrefixes(changes);
      if (cr.isNotEmpty) {
        merged = _mergeNotesAndComment(merged, 'Requested changes:\n$cr');
      }
      final c = _stripFeedbackLabelPrefixes(comment);
      if (c.isNotEmpty && c.toLowerCase() != cr.toLowerCase()) {
        merged = _mergeNotesAndComment(merged, 'Comment:\n$c');
      }
    } else {
      merged = _mergeNotesAndComment(merged, comment);
      if (changes.isNotEmpty) {
        merged = _mergeNotesAndComment(merged, changes);
      }
    }

    return merged;
  }

  List<pw.Widget> _buildKeepHeaderWithFirstParagraphSection({
    required String title,
    required String text,
    double fontSize = 10,
  }) {
    final t = text.trim().isEmpty ? '-' : text.trim();
    final parts = t
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final paragraphs = parts.isEmpty ? <String>['-'] : parts;
    final first = paragraphs.first;
    final rest = paragraphs.length <= 1 ? const <String>[] : paragraphs.sublist(1);

    final widgets = <pw.Widget>[];
    widgets.add(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _subSectionHeader(title),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: pw.Text(first, style: pw.TextStyle(fontSize: fontSize)),
          ),
        ],
      ),
    );
    for (final p in rest) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          child: pw.Text(p, style: pw.TextStyle(fontSize: fontSize)),
        ),
      );
      widgets.add(pw.SizedBox(height: 8));
    }
    if (widgets.length > 1 && widgets.last is pw.SizedBox) {
      widgets.removeLast();
    }
    return widgets;
  }

  String _stripFeedbackFromBody(String content) {
    final lines = content.split('\n');
    final out = <String>[];
    var skipping = false;
    for (final line in lines) {
      final t = line.trim().toUpperCase();
      if (!skipping &&
          (t == 'CLIENT FEEDBACK' ||
              t == 'USER FEEDBACK' ||
              t.startsWith('CLIENT FEEDBACK:') ||
              t.startsWith('USER FEEDBACK:') ||
              t.startsWith('FEEDBACK:'))) {
        skipping = true;
        continue;
      }
      if (skipping) {
        if (t.isEmpty) continue;
        if (t == 'SIGN-OFF NOTES' || t == 'SIGN OFF NOTES' || t == 'SIGNOFF NOTES') {
          skipping = false;
          out.add('SIGN-OFF NOTES');
        }
        continue;
      }
      out.add(line);
    }
    return out.join('\n').trim();
  }

  String _stripSignOffNotesFromBody(String content) {
    final lines = content.split('\n');
    final out = <String>[];
    var skipping = false;

    bool isHeaderLine(String line) {
      final t = line.trim();
      if (t.isEmpty) return false;
      if (t.contains(':')) return false;
      if (t.startsWith('-')) return false;
      final upper = t.toUpperCase();
      if (upper != t) return false;
      return t.length <= 40;
    }

    for (final raw in lines) {
      final line = raw.trimRight();
      final t = line.trim().toUpperCase();

      if (!skipping && (t == 'SIGN-OFF NOTES' || t == 'SIGN OFF NOTES' || t == 'SIGNOFF NOTES')) {
        skipping = true;
        continue;
      }

      if (skipping) {
        if (isHeaderLine(line) && t != 'SIGN-OFF NOTES' && t != 'SIGN OFF NOTES' && t != 'SIGNOFF NOTES') {
          skipping = false;
          out.add(line.trim());
        }
        continue;
      }

      out.add(line.trim());
    }

    return out.join('\n').trim();
  }

  Map<String, List<String>> _parseReportSections(String content) {
    final sections = <String, List<String>>{};
    String current = 'BODY';
    sections[current] = <String>[];

    bool isHeaderLine(String line) {
      final t = line.trim();
      if (t.isEmpty) return false;
      if (t.contains(':')) return false;
      if (t.startsWith('-')) return false;
      final upper = t.toUpperCase();
      if (upper != t) return false;
      return t.length <= 40;
    }

    for (final raw in content.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) continue;
      if (isHeaderLine(line)) {
        current = line.trim().toUpperCase();
        sections.putIfAbsent(current, () => <String>[]);
        continue;
      }
      sections.putIfAbsent(current, () => <String>[]).add(line.trim());
    }
    return sections;
  }

  Map<String, String> _parseKeyValues(List<String>? lines) {
    final out = <String, String>{};
    if (lines == null) return out;
    for (final l in lines) {
      final idx = l.indexOf(':');
      if (idx <= 0) continue;
      final k = l.substring(0, idx).trim();
      final v = l.substring(idx + 1).trim();
      if (k.isEmpty) continue;
      out[k] = v;
    }
    return out;
  }

  List<pw.Widget> _buildStructuredBodyWidgets(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return [
        _subSectionHeader('REPORT CONTENT'),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: pw.Text('-', style: const pw.TextStyle(fontSize: 10)),
        ),
      ];
    }

    final sections = _parseReportSections(trimmed);
    final ordered = <String>[
      'PROJECT',
      'PROJECT SPRINT TOTALS',
      'SPRINT',
      'SPRINT SUMMARY',
      'TEAM MEMBERS',
      'DELIVERABLES',
    ];

    bool hasAny = false;
    for (final k in ordered) {
      if ((sections[k] ?? const <String>[]).isNotEmpty) {
        hasAny = true;
        break;
      }
    }

    if (!hasAny) {
      return [
        _subSectionHeader('REPORT CONTENT'),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: pw.Text(trimmed, style: const pw.TextStyle(fontSize: 10)),
        ),
      ];
    }

    pw.Widget kvList(String header) {
      final kv = _parseKeyValues(sections[header]);
      final lines = sections[header] ?? const <String>[];
      if (kv.isEmpty) {
        final text = lines.isEmpty ? '-' : lines.join('\n');
        return pw.Text(text, style: const pw.TextStyle(fontSize: 10));
      }
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: kv.entries.map((e) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: '${e.key}: ',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                  ),
                  pw.TextSpan(
                    text: e.value.isEmpty ? '-' : e.value,
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }

    pw.Widget lineList(String header, {double fontSize = 10}) {
      final lines = (sections[header] ?? const <String>[]).where((l) => l.trim().isNotEmpty).toList();
      return pw.Text(lines.isEmpty ? '-' : lines.join('\n'), style: pw.TextStyle(fontSize: fontSize));
    }

    final widgets = <pw.Widget>[];
    for (final header in ordered) {
      final lines = sections[header] ?? const <String>[];
      if (lines.isEmpty) continue;
      widgets.add(_subSectionHeader(header));
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: (header == 'PROJECT' || header == 'PROJECT SPRINT TOTALS' || header == 'SPRINT' || header == 'SPRINT SUMMARY')
              ? kvList(header)
              : (header == 'DELIVERABLES' ? lineList(header, fontSize: 9.5) : lineList(header)),
        ),
      );
      widgets.add(pw.SizedBox(height: 8));
    }
    if (widgets.isNotEmpty) widgets.removeLast();
    return widgets;
  }

  String _sanitizeRibbonTitle(String title) {
    var t = title.trim();
    if (t.isEmpty) return '-';
    final newline = t.indexOf('\n');
    if (newline != -1) t = t.substring(0, newline).trim();
    final lowered = t.toLowerCase();
    const markers = [
      'client feedback',
      'user feedback',
      'feedback:',
      'feedback -',
      'comment:',
      'comments:',
      'notes:',
    ];
    for (final m in markers) {
      final idx = lowered.indexOf(m);
      if (idx > 0) {
        t = t.substring(0, idx).trim();
        break;
      }
    }
    if (t.length > 60) t = t.substring(0, 60).trim();
    return t.isEmpty ? '-' : t;
  }

  String _resolveRibbonTitle({
    required String reportTitle,
    required String reportContent,
    required String? signOffText,
    required String? clientComment,
  }) {
    String? titleFromContent;
    for (final raw in reportContent.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final match = RegExp(r'^(title)\s*:\s*(.+)$', caseSensitive: false).firstMatch(line);
      if (match != null) {
        titleFromContent = match.group(2)?.trim();
        if (titleFromContent != null && titleFromContent.isNotEmpty) break;
      }
    }

    final sanitizedExplicit = titleFromContent == null ? '' : _sanitizeRibbonTitle(titleFromContent);
    if (sanitizedExplicit.isNotEmpty && sanitizedExplicit != '-') return sanitizedExplicit;

    final sanitized = _sanitizeRibbonTitle(reportTitle);
    if (sanitized == '-') return '';

    final note = (signOffText ?? '').trim();
    final comment = (clientComment ?? '').trim();
    final s = sanitized.trim();
    if (comment.isNotEmpty && s.toLowerCase() == comment.toLowerCase()) return '';
    if (note.isNotEmpty && (note.toLowerCase() == s.toLowerCase() || note.toLowerCase().contains(s.toLowerCase()))) return '';
    if (s.split(RegExp(r'\s+')).length <= 3 &&
        RegExp(r'^(complete|fix|update|done|ok|okay)\b', caseSensitive: false).hasMatch(s)) {
      return '';
    }
    return sanitized;
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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

  bool _looksLikeBase64ImageData(String value) {
    final t = value.trim();
    if (t.isEmpty) return false;
    if (t.startsWith('data:image', 0)) return true;
    if (t.contains('base64,')) return true;
    final compact = t.replaceAll(RegExp(r'\s+'), '');
    if (compact.length < 40) return false;
    if (!RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(compact)) return false;
    return true;
  }

  String _normalizeBase64ForDecode(String value) {
    var s = value.trim();
    if (s.contains(',')) s = s.split(',').last;
    s = s.replaceAll(RegExp(r'\s+'), '');
    s = s.replaceAll('-', '+').replaceAll('_', '/');
    final mod = s.length % 4;
    if (mod != 0) {
      s = s.padRight(s.length + (4 - mod), '=');
    }
    return s;
  }

  pw.Widget _buildSignatureVisual(String? signatureData, String signatureType) {
    final s = (signatureData ?? '').trim();
    if (s.isEmpty) {
      return pw.Container(
        color: PdfColors.grey200,
        child: pw.Center(
          child: pw.Text('-'),
        ),
      );
    }

    final t = signatureType.toLowerCase().trim();
    if (t == 'typed' && !_looksLikeBase64ImageData(s)) {
      return pw.Center(
        child: pw.Text(
          s,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 14,
            fontStyle: pw.FontStyle.italic,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );
    }

    return _buildSignatureImage(s);
  }

  Map<String, dynamic>? _pickPreparedBySignatureMap({
    required SignOffReport report,
    required List<Map<String, dynamic>> signatures,
  }) {
    final preparedId = (report.preparedBy ?? '').trim();
    final createdId = report.createdBy.trim();
    final preparedName = (report.preparedByName ?? '').trim().toLowerCase();

    Map<String, dynamic>? match;
    for (final sig in signatures) {
      final sid = (sig['signer_id'] ?? '').toString().trim();
      final sname = (sig['signer_name'] ?? '').toString().trim().toLowerCase();
      final srole = (sig['signer_role'] ?? '').toString().trim().toLowerCase();
      if (preparedId.isNotEmpty && sid == preparedId) {
        match = sig;
        break;
      }
      if (createdId.isNotEmpty && sid == createdId) {
        match = sig;
        break;
      }
      if (preparedName.isNotEmpty && sname == preparedName) {
        match = sig;
        break;
      }
      if (srole.contains('prepared')) {
        match = sig;
        break;
      }
    }
    if (match != null) return match;

    final reportSig = (report.digitalSignature ?? '').trim();
    if (reportSig.isNotEmpty) {
      return {
        'signature_data': reportSig,
        'signature_type': 'manual',
        'signed_at': report.createdAt.toIso8601String(),
        'signer_id': report.preparedBy ?? report.createdBy,
        'signer_name': report.preparedByName,
        'signer_role': report.preparedByRole,
      };
    }

    return null;
  }

  String? _pickPreparedBySignatureData({
    required SignOffReport report,
    required List<Map<String, dynamic>> signatures,
  }) {
    final m = _pickPreparedBySignatureMap(report: report, signatures: signatures);
    final v = (m == null ? '' : (m['signature_data'] ?? '').toString()).trim();
    return v.isEmpty ? null : v;
  }

  String _pickPreparedBySignatureType({
    required SignOffReport report,
    required List<Map<String, dynamic>> signatures,
  }) {
    final m = _pickPreparedBySignatureMap(report: report, signatures: signatures);
    final v = (m == null ? '' : (m['signature_type'] ?? '').toString()).trim();
    return v.isEmpty ? 'manual' : v;
  }

  Map<String, dynamic>? _pickReviewerSignatureMap({
    required SignOffReport report,
    required List<Map<String, dynamic>> signatures,
  }) {
    final others = _removePreparedByFromSignatures(signatures: signatures, report: report);
    if (others.isNotEmpty) {
      DateTime? parseSignedAt(Map<String, dynamic> sig) {
        final raw = (sig['signed_at'] ?? sig['signedAt'] ?? '').toString().trim();
        if (raw.isEmpty) return null;
        return DateTime.tryParse(raw);
      }

      others.sort((a, b) {
        final da = parseSignedAt(a);
        final db = parseSignedAt(b);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
      return others.first;
    }

    final prepared = _pickPreparedBySignatureData(report: report, signatures: signatures);
    final reportSig = (report.digitalSignature ?? '').trim();
    if (reportSig.isNotEmpty &&
        (prepared == null || prepared.trim().isEmpty || prepared.trim() != reportSig)) {
      return {
        'signature_data': reportSig,
        'signature_type': 'manual',
        'signed_at': (report.approvedAt ?? report.reviewedAt ?? report.createdAt).toIso8601String(),
        'signer_id': report.approvedBy ?? report.reviewedBy,
        'signer_name': report.approvedByName ?? report.reviewedByName,
        'signer_role': report.approvedByRole ?? report.reviewedByRole,
      };
    }

    return null;
  }

  String? _pickReviewerSignatureData({
    required SignOffReport report,
    required List<Map<String, dynamic>> signatures,
  }) {
    final m = _pickReviewerSignatureMap(report: report, signatures: signatures);
    final v = (m == null ? '' : (m['signature_data'] ?? '').toString()).trim();
    return v.isEmpty ? null : v;
  }

  String _pickReviewerSignatureType({
    required SignOffReport report,
    required List<Map<String, dynamic>> signatures,
  }) {
    final m = _pickReviewerSignatureMap(report: report, signatures: signatures);
    final v = (m == null ? '' : (m['signature_type'] ?? '').toString()).trim();
    return v.isEmpty ? 'manual' : v;
  }

  List<Map<String, dynamic>> _removePreparedByFromSignatures({
    required List<Map<String, dynamic>> signatures,
    required SignOffReport report,
  }) {
    final prepared = _pickPreparedBySignatureMap(report: report, signatures: signatures);
    if (prepared == null) return signatures;
    final data = (prepared['signature_data'] ?? '').toString().trim();
    final preparedId = (prepared['signer_id'] ?? '').toString().trim();
    final preparedName = (prepared['signer_name'] ?? '').toString().trim().toLowerCase();

    return signatures.where((sig) {
      final sigData = (sig['signature_data'] ?? '').toString().trim();
      final sigId = (sig['signer_id'] ?? '').toString().trim();
      final sigName = (sig['signer_name'] ?? '').toString().trim().toLowerCase();
      if (data.isNotEmpty && sigData == data) return false;
      if (preparedId.isNotEmpty && sigId == preparedId) return false;
      if (preparedName.isNotEmpty && sigName == preparedName) return false;
      return true;
    }).toList();
  }

  pw.Widget _buildPreparedBySignatureSection({
    required String preparedByName,
    required String? preparedByRole,
    required DateTime signedAt,
    required String? signatureData,
    required String signatureType,
  }) {
    final name = preparedByName.trim().isEmpty ? '-' : preparedByName.trim();
    final role = (preparedByRole ?? '').trim();
    final hasSig = (signatureData ?? '').trim().isNotEmpty;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _subSectionHeader('PREPARED BY'),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 210,
                height: 100,
                margin: const pw.EdgeInsets.only(right: 15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey600),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.ClipRRect(
                  horizontalRadius: 4,
                  verticalRadius: 4,
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Center(child: _buildSignatureVisual(signatureData, signatureType)),
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      name,
                      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                    ),
                    if (role.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        role,
                        style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                      ),
                    ],
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Signed: ${_formatDate(signedAt)}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                    ),
                    if (hasSig) ...[
                      pw.SizedBox(height: 8),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.green100,
                          borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
                        ),
                        child: pw.Text(
                          'VERIFIED',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.green900,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildReviewedBySignatureSection({
    required String label,
    required String reviewerName,
    required String? reviewerRole,
    required DateTime? signedAt,
    required String? signatureData,
    required String signatureType,
  }) {
    final name = reviewerName.trim().isEmpty ? '-' : reviewerName.trim();
    final role = (reviewerRole ?? '').trim();
    final hasSig = (signatureData ?? '').trim().isNotEmpty;
    final at = signedAt ?? DateTime.now();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _subSectionHeader(label),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 210,
                height: 100,
                margin: const pw.EdgeInsets.only(right: 15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey600),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.ClipRRect(
                  horizontalRadius: 4,
                  verticalRadius: 4,
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Center(child: _buildSignatureVisual(signatureData, signatureType)),
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      name,
                      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                    ),
                    if (role.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        role,
                        style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                      ),
                    ],
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Signed: ${_formatDate(at)}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                    ),
                    if (hasSig) ...[
                      pw.SizedBox(height: 8),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.green100,
                          borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
                        ),
                        child: pw.Text(
                          'VERIFIED',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.green900,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build signature image with error handling for PDF export
  pw.Widget _buildSignatureImage(String? signatureData) {
    if (signatureData == null || signatureData.isEmpty) {
      return pw.Container(
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
          color: PdfColors.grey200,
          child: pw.Center(
            child: pw.Text('Invalid signature data'),
          ),
        );
      }

      if (!_looksLikeBase64ImageData(trimmedData)) {
        final shown = trimmedData.length > 60 ? '${trimmedData.substring(0, 60)}…' : trimmedData;
        return pw.Container(
          color: PdfColors.grey200,
          child: pw.Center(
            child: pw.Text(
              shown.isEmpty ? '-' : shown,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        );
      }

      final normalized = _normalizeBase64ForDecode(trimmedData);
      final Uint8List imageBytes = base64Decode(normalized);
      
      return pw.Image(
        pw.MemoryImage(imageBytes),
        fit: pw.BoxFit.contain,
      );
    } catch (e) {
      return pw.Container(
        color: PdfColors.grey200,
        child: pw.Center(
          child: pw.Text('Invalid signature format'),
        ),
      );
    }
  }
}

