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
  Future<Map<String, String>>? _cachedProjectSprintTotalsFuture;
  String? _cachedProjectSprintTotalsKey;
  
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
          final enrichedSprintReport =
              await _enrichSprintReportWithProjectTotals(sprintReport);
          final pdf = _buildSprintSignOffPdf(
            report: effectiveReport,
            sprintReport: enrichedSprintReport,
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

      final sanitizedContent =
          SignOffReport.sanitizeReportContent(effectiveReport.reportContent);
      final normalizedContent = _sanitizeContentForPdf(sanitizedContent);
      final reportBodyContent =
          _stripSignOffNotesFromBody(_stripFeedbackFromBody(normalizedContent));
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
              reportContent: normalizedContent,
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
              pw.SizedBox(height: 8),
              _subSectionHeader('SIGN-OFF NOTES'),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: pw.Text(
                  signOffNotesText.trim().isEmpty ? '-' : signOffNotesText.trim(),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.SizedBox(height: 8),
              _subSectionHeader('DIGITAL SIGNATURES'),
              pw.SizedBox(height: 8),
              _buildPreparedBySignatureSection(
                preparedByName: effectiveReport.preparedByName ?? effectiveReport.createdBy,
                preparedByRole: effectiveReport.preparedByRole,
                signedAt: effectiveReport.createdAt,
                signatureData: preparedSigData,
                signatureType: preparedSigType,
                includeHeader: false,
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
                  includeHeader: false,
                ),
              ],
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
          final enrichedSprintReport =
              await _enrichSprintReportWithProjectTotals(sprintReport);
          final sprintPdf = _buildSprintSignOffPdf(
            report: effectiveReport,
            sprintReport: enrichedSprintReport,
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
      final sanitizedContent =
          SignOffReport.sanitizeReportContent(effectiveReport.reportContent);
      final normalizedContent = _sanitizeContentForPdf(sanitizedContent);
      final reportBodyContent =
          _stripSignOffNotesFromBody(_stripFeedbackFromBody(normalizedContent));
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
              reportContent: normalizedContent,
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
    final normalizedOriginalContent = _sanitizeContentForPdf(content);

    if (useSignOffTemplate) {
      final header = await _getHeaderAssets();
      final footer = await _getFooterAssets();
      final effectiveContent =
          await _buildCanonicalSprintSignOffContentIfPossible(normalizedOriginalContent);
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
            final reportBodyContent = _stripSignOffNotesFromBody(
                _stripFeedbackFromBody(effectiveContent));
            final signOffNotesText = _buildSignOffNotesText(
              reportContent: effectiveContent,
              clientComment: null,
              changeRequestDetails: null,
              status: ReportStatus.draft,
            );
            return [
              pw.SizedBox(height: 6),
              ..._buildStructuredBodyWidgets(reportBodyContent),
              pw.SizedBox(height: 8),
              _subSectionHeader('SIGN-OFF NOTES'),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: pw.Text(
                  signOffNotesText.trim().isEmpty ? '-' : signOffNotesText.trim(),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.SizedBox(height: 8),
              _subSectionHeader('DIGITAL SIGNATURES'),
              pw.SizedBox(height: 8),
              _buildPreparedBySignatureSection(
                preparedByName: preparedByName.isEmpty ? '-' : preparedByName,
                preparedByRole: preparedByRole,
                signedAt: signedAt,
                signatureData: signatureData,
                signatureType: signatureType,
                includeHeader: false,
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
              normalizedOriginalContent,
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
      final logoData = await rootBundle.load('assets/khono_logo.png');
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
    try {
      final regular =
          await rootBundle.load('assets/fonts/fonts/poppins/Poppins-Regular.ttf');
      final bold =
          await rootBundle.load('assets/fonts/fonts/poppins/Poppins-Bold.ttf');
      return _PdfFontAssets(
        base: pw.Font.ttf(regular),
        bold: pw.Font.ttf(bold),
      );
    } catch (_) {
      return _PdfFontAssets(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      );
    }
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
    final showMeta = status.isNotEmpty || createdBy.isNotEmpty;
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: pw.Stack(
        children: [
          if (showMeta)
            pw.Positioned(
              right: 0,
              top: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (status.isNotEmpty)
                    pw.Text(
                      'Status: $status',
                      style: pw.TextStyle(
                        color: PdfColors.grey700,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  if (createdBy.isNotEmpty)
                    pw.Text(
                      'Created by: $createdBy',
                      style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
                    ),
                ],
              ),
            ),
          pw.Center(
            child: logo == null
                ? pw.SizedBox(height: 22)
                : pw.Image(logo, height: 22, fit: pw.BoxFit.contain),
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

    final normalizedReportContent = _sanitizeContentForPdf(report.reportContent);
    final sections = _parseReportSections(normalizedReportContent);
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
      reportContent: normalizedReportContent,
      signOffText: signOffTextFromSection,
      clientComment: report.clientComment,
    );
    final ribbonTitle = resolvedTitle.isEmpty ? (sprintName.isEmpty ? '-' : sprintName) : resolvedTitle;

    pw.Widget kvRow(String k, String v) {
      final safeV = _sanitizeContentForPdf(v);
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(text: '${k.trim()}: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
              pw.TextSpan(text: safeV.trim().isEmpty ? '-' : safeV.trim(), style: const pw.TextStyle(fontSize: 9, color: PdfColors.black)),
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
      reportContent: normalizedReportContent,
      clientComment: report.clientComment,
      changeRequestDetails: report.changeRequestDetails,
      status: report.status,
    );

    final sprintMap = sprintReport['sprint'] is Map
        ? Map<String, dynamic>.from(sprintReport['sprint'] as Map)
        : <String, dynamic>{};
    final summaryMap = sprintReport['summary'] is Map
        ? Map<String, dynamic>.from(sprintReport['summary'] as Map)
        : <String, dynamic>{};
    final projectMap = sprintReport['project'] is Map
        ? Map<String, dynamic>.from(sprintReport['project'] as Map)
        : (sprintMap['project'] is Map
            ? Map<String, dynamic>.from(sprintMap['project'] as Map)
            : <String, dynamic>{});
    final projectTotalsMap = sprintReport['projectSprintTotals'] is Map
        ? Map<String, dynamic>.from(sprintReport['projectSprintTotals'] as Map)
        : <String, dynamic>{};
    final teamMap = sprintReport['team'] is Map
        ? Map<String, dynamic>.from(sprintReport['team'] as Map)
        : <String, dynamic>{};
    final deliverablesList = sprintReport['deliverables'] is List
        ? (sprintReport['deliverables'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    String safeString(dynamic v) => _sanitizeContentForPdf(v?.toString() ?? '').trim();
    String firstNonEmpty(List<String> values) {
      for (final v in values) {
        final t = v.trim();
        if (t.isNotEmpty && t != '-') return t;
      }
      return '-';
    }

    final projectName = firstNonEmpty([
      projectKv['Name'] ?? '',
      projectKv['NAME'] ?? '',
      safeString(projectMap['name']),
      safeString(sprintMap['project_name']),
    ]);
    final projectKey = firstNonEmpty([
      projectKv['Key'] ?? '',
      projectKv['KEY'] ?? '',
      safeString(projectMap['key']),
      safeString(sprintMap['project_key']),
    ]);
    final projectId = firstNonEmpty([
      projectKv['ID'] ?? '',
      projectKv['Id'] ?? '',
      safeString(projectMap['id']),
      safeString(sprintMap['project_id']),
    ]);

    final totalSprints = firstNonEmpty([
      totalsKv['Total Sprints'] ?? '',
      totalsKv['Total'] ?? '',
      safeString(projectTotalsMap['Total Sprints']),
      safeString(projectTotalsMap['total']),
      safeString(projectTotalsMap['totalSprints']),
      safeString(projectTotalsMap['total_sprints']),
    ]);
    final completedSprints = firstNonEmpty([
      totalsKv['Completed Sprints'] ?? '',
      safeString(projectTotalsMap['Completed Sprints']),
      safeString(projectTotalsMap['completed']),
      safeString(projectTotalsMap['completedSprints']),
      safeString(projectTotalsMap['completed_sprints']),
    ]);
    final sprintSuccessRate = firstNonEmpty([
      totalsKv['Sprint Success Rate'] ?? '',
      safeString(projectTotalsMap['Sprint Success Rate']),
      safeString(projectTotalsMap['successRate']),
      safeString(projectTotalsMap['sprintSuccessRate']),
      safeString(projectTotalsMap['success_rate']),
    ]);

    final sprintNameEffective = firstNonEmpty([
      sprintKv['Name'] ?? '',
      safeString(sprintMap['name']),
    ]);
    final sprintIdEffective = firstNonEmpty([
      sprintKv['ID'] ?? sprintKv['Id'] ?? '',
      safeString(sprintMap['id']),
    ]);
    final sprintStatus = firstNonEmpty([
      sprintKv['Status'] ?? '',
      safeString(sprintMap['status']),
    ]);
    final sprintStart = firstNonEmpty([
      sprintKv['Start'] ?? '',
      safeString(sprintMap['start_date']),
      safeString(sprintMap['startDate']),
    ]);
    final sprintEnd = firstNonEmpty([
      sprintKv['End'] ?? '',
      safeString(sprintMap['end_date']),
      safeString(sprintMap['endDate']),
    ]);

    final totalDeliverables = firstNonEmpty([
      summaryKv['Total Deliverables'] ?? '',
      safeString(summaryMap['total_deliverables']),
      safeString(summaryMap['totalDeliverables']),
    ]);
    final completedDeliverables = firstNonEmpty([
      summaryKv['Completed'] ?? '',
      safeString(summaryMap['completed']),
    ]);
    final inProgressDeliverables = firstNonEmpty([
      summaryKv['In Progress'] ?? '',
      safeString(summaryMap['in_progress']),
      safeString(summaryMap['inProgress']),
    ]);
    final notStartedDeliverables = firstNonEmpty([
      summaryKv['Not Started'] ?? '',
      safeString(summaryMap['not_started']),
      safeString(summaryMap['notStarted']),
    ]);
    final overdueDeliverables = firstNonEmpty([
      summaryKv['Overdue'] ?? '',
      safeString(summaryMap['overdue']),
    ]);
    final blockedDeliverables = firstNonEmpty([
      summaryKv['Blocked'] ?? '',
      safeString(summaryMap['blocked']),
    ]);
    final sprintProgress = firstNonEmpty([
      summaryKv['Sprint Progress'] ?? '',
      safeString(summaryMap['sprint_progress']),
      safeString(summaryMap['sprintProgress']),
      safeString(summaryMap['progress']),
    ]);
    final completionRate = firstNonEmpty([
      summaryKv['Completion Rate'] ?? '',
      safeString(summaryMap['completion_rate']),
      safeString(summaryMap['completionRate']),
    ]);
    final health = firstNonEmpty([
      summaryKv['Health'] ?? '',
      safeString(summaryMap['health']),
    ]);

    List<String> teamLinesEffective = teamLines;
    if (teamLinesEffective.isEmpty) {
      final members = teamMap['members'];
      if (members is List) {
        teamLinesEffective = members.whereType<Map>().map((m) {
          final mm = Map<String, dynamic>.from(m);
          final name = safeString(mm['name'] ?? mm['full_name'] ?? mm['fullName']);
          final email = safeString(mm['email']);
          final role = safeString(mm['role'] ?? mm['user_role'] ?? mm['userRole']);
          final parts = <String>[];
          if (name.isNotEmpty && name != '-') parts.add(name);
          if (email.isNotEmpty && email != '-') parts.add(email);
          if (role.isNotEmpty && role != '-') parts.add(role);
          return parts.isEmpty ? '-' : parts.join(' | ');
        }).toList();
      }
    }

    List<String> deliverableLinesEffective = deliverableLines;
    if (deliverableLinesEffective.isEmpty && deliverablesList.isNotEmpty) {
      deliverableLinesEffective = deliverablesList.map((d) {
        final name = safeString(d['name'] ?? d['title'] ?? d['deliverable_name'] ?? d['deliverableName']);
        final owner = safeString(d['owner'] ?? d['owner_name'] ?? d['ownerName'] ?? d['assignee'] ?? d['assignee_name'] ?? d['assigneeName']);
        final status = safeString(d['status'] ?? d['state']);
        final progress = safeString(d['progress'] ?? d['percent_complete'] ?? d['percentComplete']);
        final due = safeString(d['due_date'] ?? d['dueDate'] ?? d['due']);
        final completedAt = safeString(d['completed_at'] ?? d['completedAt'] ?? d['completed']);
        final category = safeString(d['category'] ?? d['type']);
        final overdue = safeString(d['overdue']);
        final parts = <String>[];
        parts.add(name.isEmpty || name == '-' ? 'Deliverable' : name);
        if (owner.isNotEmpty && owner != '-') parts.add('Owner: $owner');
        if (status.isNotEmpty && status != '-') parts.add('Status: $status');
        if (progress.isNotEmpty && progress != '-') parts.add('Progress: $progress');
        if (due.isNotEmpty && due != '-') parts.add('Due: $due');
        if (completedAt.isNotEmpty && completedAt != '-') parts.add('Completed: $completedAt');
        if (category.isNotEmpty && category != '-') parts.add('Category: $category');
        if (overdue.isNotEmpty && overdue != '-') parts.add('Overdue: $overdue');
        return '- ${parts.join(' | ')}';
      }).toList();
    }

    pw.Widget twoCol(pw.Widget left, pw.Widget right) {
      return pw.Table(
        columnWidths: const {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(1)},
        children: [
          pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.all(0), child: left),
            pw.Padding(padding: const pw.EdgeInsets.all(0), child: right),
          ]),
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
              cell('Project Detail:', [
                kvRow('Name', projectName),
                kvRow('Key', projectKey),
                kvRow('ID', projectId),
              ]),
              cell('Project Sprint Totals:', [
                kvRow('Total Sprints', totalSprints),
                kvRow('Completed Sprints', completedSprints),
                kvRow('Sprint Success Rate', sprintSuccessRate),
              ]),
            ),
            pw.SizedBox(height: 8),
            twoCol(
              cell('Sprint Detail:', [
                kvRow('Name', sprintNameEffective),
                kvRow('ID', sprintIdEffective),
                kvRow('Status', sprintStatus),
                kvRow('Start', sprintStart),
                kvRow('End', sprintEnd),
              ]),
              cell('Sprint Summary:', [
                kvRow('Total Deliverables', totalDeliverables),
                kvRow('Completed', completedDeliverables),
                kvRow('In Progress', inProgressDeliverables),
                kvRow('Not Started', notStartedDeliverables),
                kvRow('Overdue', overdueDeliverables),
                kvRow('Blocked', blockedDeliverables),
                kvRow('Sprint Progress', sprintProgress),
                kvRow('Completion Rate', completionRate),
                kvRow('Health', health.toUpperCase()),
              ]),
            ),
            pw.SizedBox(height: 8),
            section(
              'TEAM MEMBERS',
              pw.Text(
                teamLinesEffective.isEmpty ? '-' : teamLinesEffective.join('\n'),
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
            pw.SizedBox(height: 8),
            section(
              'DELIVERABLES',
              pw.Text(
                deliverableLinesEffective.isEmpty ? '-' : deliverableLinesEffective.join('\n'),
                style: const pw.TextStyle(fontSize: 8.5),
              ),
            ),
            pw.SizedBox(height: 8),
            section(
              'SIGN-OFF NOTES',
              pw.Text(signOffText.trim().isEmpty ? '-' : signOffText, style: const pw.TextStyle(fontSize: 9)),
            ),
            pw.SizedBox(height: 8),
            _subSectionHeader('DIGITAL SIGNATURES'),
            pw.SizedBox(height: 8),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _buildPreparedBySignatureSection(
                  preparedByName: report.preparedByName ?? report.createdBy,
                  preparedByRole: report.preparedByRole,
                  signedAt: report.createdAt,
                  signatureData: _pickPreparedBySignatureData(report: report, signatures: signatures),
                  signatureType: _pickPreparedBySignatureType(report: report, signatures: signatures),
                  includeHeader: false,
                ),
                if ((_pickReviewerSignatureData(report: report, signatures: signatures) ?? '').trim().isNotEmpty ||
                    ((report.approvedByName ?? report.reviewedByName ?? report.approvedBy ?? report.reviewedBy) ?? '')
                        .trim()
                        .isNotEmpty ||
                    report.reviewedAt != null ||
                    report.approvedAt != null ||
                    report.status == ReportStatus.approved ||
                    report.status == ReportStatus.changeRequested ||
                    report.status == ReportStatus.underReview) ...[
                  pw.SizedBox(height: 8),
                  _buildReviewedBySignatureSection(
                    label: report.status == ReportStatus.approved
                        ? 'APPROVED BY'
                        : (report.status == ReportStatus.changeRequested
                            ? 'CHANGES REQUESTED BY'
                            : 'REVIEWED BY'),
                    reviewerName: ((report.status == ReportStatus.approved
                                    ? (report.approvedByName ??
                                        report.reviewedByName ??
                                        report.approvedBy ??
                                        report.reviewedBy)
                                    : (report.reviewedByName ??
                                        report.approvedByName ??
                                        report.reviewedBy ??
                                        report.approvedBy)) ??
                                '-')
                            .trim()
                            .isEmpty
                        ? '-'
                        : ((report.status == ReportStatus.approved
                                    ? (report.approvedByName ??
                                        report.reviewedByName ??
                                        report.approvedBy ??
                                        report.reviewedBy)
                                    : (report.reviewedByName ??
                                        report.approvedByName ??
                                        report.reviewedBy ??
                                        report.approvedBy)) ??
                                '-')
                            .trim(),
                    reviewerRole: (report.status == ReportStatus.approved
                            ? (report.approvedByRole ?? report.reviewedByRole)
                            : (report.reviewedByRole ?? report.approvedByRole))
                        ?.trim(),
                    signedAt: report.status == ReportStatus.approved
                        ? (report.approvedAt ?? report.reviewedAt)
                        : (report.reviewedAt ?? report.approvedAt),
                    signatureData: _pickReviewerSignatureData(report: report, signatures: signatures),
                    signatureType: _pickReviewerSignatureType(report: report, signatures: signatures),
                    includeHeader: false,
                  ),
                ],
              ],
            ),
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

  String _extractSignOffNote(String reportContent) {
    final raw = reportContent;
    final lines = raw.split('\n');
    final startIdx = lines.indexWhere((l) => l.trim().toUpperCase() == 'SIGN-OFF NOTES');
    if (startIdx == -1) return '';
    final buf = <String>[];
    bool isHeaderLine(String line) {
      final t = line.trim();
      if (t.isEmpty) return false;
      if (t.contains(':')) return false;
      if (t.startsWith('-')) return false;
      final upper = t.toUpperCase();
      if (upper != t) return false;
      return t.length <= 40;
    }

    for (var i = startIdx + 1; i < lines.length; i++) {
      final rawLine = lines[i].trimRight();
      final t = rawLine.trim();
      if (t.isEmpty) continue;
      if (isHeaderLine(t) && t.toUpperCase() != 'SIGN-OFF NOTES') break;
      buf.add(t);
    }
    return _stripFeedbackLabelPrefixes(buf.join('\n')).trim();
  }

  String _extractFeedbackText(String reportContent) {
    final sections = _parseReportSections(reportContent);
    final out = <String>[];

    void addLines(List<String>? lines) {
      if (lines == null) return;
      for (final l in lines) {
        final t = l.trim();
        if (t.isEmpty) continue;
        out.add(t);
      }
    }

    addLines(sections['USER FEEDBACK']);
    addLines(sections['CLIENT FEEDBACK']);
    addLines(sections['FEEDBACK']);

    final inline = RegExp(
      r'^(?:[-•*]+\s*)?(?:user|client)?\s*feedback\s*[:\\-–—]\\s*(.+)$',
      caseSensitive: false,
    );
    for (final entry in sections.entries) {
      if (entry.key == 'SIGN-OFF NOTES') continue;
      for (final line in entry.value) {
        final m = inline.firstMatch(line.trim());
        if (m != null) {
          final v = (m.group(1) ?? '').trim();
          if (v.isNotEmpty) out.add(v);
        }
      }
    }

    return _stripFeedbackLabelPrefixes(out.join('\n')).trim();
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
    final feedback = _extractFeedbackText(reportContent);

    final parts = <String>[
      _stripFeedbackLabelPrefixes(note),
      _stripFeedbackLabelPrefixes(comment),
      _stripFeedbackLabelPrefixes(changes),
      _stripFeedbackLabelPrefixes(feedback),
    ].where((p) => p.trim().isNotEmpty && p.trim() != '-').toList();

    final deduped = <String>[];
    for (final p in parts) {
      final v = p.trim();
      final lower = v.toLowerCase();
      final exists = deduped.any((d) {
        final dl = d.toLowerCase();
        return dl == lower || dl.contains(lower) || lower.contains(dl);
      });
      if (!exists) deduped.add(v);
    }

    return deduped.isEmpty ? '-' : deduped.join('\n\n');
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

    bool isHeaderLine(String line) {
      final t = line.trim();
      if (t.isEmpty) return false;
      if (t.contains(':')) return false;
      if (t.startsWith('-')) return false;
      final upper = t.toUpperCase();
      if (upper != t) return false;
      return t.length <= 40;
    }

    bool isFeedbackHeader(String t) {
      return t == 'CLIENT FEEDBACK' ||
          t == 'USER FEEDBACK' ||
          t == 'FEEDBACK' ||
          t.startsWith('CLIENT FEEDBACK:') ||
          t.startsWith('USER FEEDBACK:') ||
          t.startsWith('FEEDBACK:');
    }

    for (final line in lines) {
      final t = line.trim().toUpperCase();
      if (!skipping && isFeedbackHeader(t)) {
        skipping = true;
        continue;
      }
      if (skipping) {
        if (isHeaderLine(line) && !isFeedbackHeader(t)) {
          skipping = false;
          out.add(line.trim());
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
    const projectKey = 'PROJECT';
    const totalsKey = 'PROJECT SPRINT TOTALS';
    const sprintKey = 'SPRINT';
    const summaryKey = 'SPRINT SUMMARY';
    const teamKey = 'TEAM MEMBERS';
    const deliverablesKey = 'DELIVERABLES';

    bool hasAny = (sections[projectKey] ?? const <String>[]).isNotEmpty ||
        (sections[totalsKey] ?? const <String>[]).isNotEmpty ||
        (sections[sprintKey] ?? const <String>[]).isNotEmpty ||
        (sections[summaryKey] ?? const <String>[]).isNotEmpty ||
        (sections[teamKey] ?? const <String>[]).isNotEmpty ||
        (sections[deliverablesKey] ?? const <String>[]).isNotEmpty;

    if (!hasAny) {
      return [
        _subSectionHeader('REPORT CONTENT'),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: pw.Text(trimmed, style: const pw.TextStyle(fontSize: 10)),
        ),
      ];
    }

    List<String> linesFor(String key) {
      return (sections[key] ?? const <String>[]).where((l) => l.trim().isNotEmpty).toList();
    }

    pw.Widget keyValueBlock(String key) {
      final kv = _parseKeyValues(linesFor(key));
      final lines = linesFor(key);
      if (kv.isEmpty) {
        return pw.Text(lines.isEmpty ? '-' : lines.join('\n'),
            style: const pw.TextStyle(fontSize: 9));
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
                    text: '${e.key.trim()}: ',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.TextSpan(
                    text: e.value.trim().isEmpty ? '-' : e.value.trim(),
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }

    pw.Widget lineBlock(String key, {double fontSize = 9}) {
      final lines = linesFor(key);
      return pw.Text(lines.isEmpty ? '-' : lines.join('\n'), style: pw.TextStyle(fontSize: fontSize));
    }

    pw.Widget cell(String title, pw.Widget child) {
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

    pw.Widget twoCol(String leftTitle, pw.Widget left, String rightTitle, pw.Widget right) {
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: cell(leftTitle, left)),
          pw.SizedBox(width: 10),
          pw.Expanded(child: cell(rightTitle, right)),
        ],
      );
    }

    final widgets = <pw.Widget>[];

    if (linesFor(projectKey).isNotEmpty || linesFor(totalsKey).isNotEmpty) {
      widgets.add(
        twoCol(
          'Project Detail:',
          keyValueBlock(projectKey),
          'Project Sprint Totals:',
          keyValueBlock(totalsKey),
        ),
      );
      widgets.add(pw.SizedBox(height: 8));
    }

    if (linesFor(sprintKey).isNotEmpty || linesFor(summaryKey).isNotEmpty) {
      widgets.add(
        twoCol(
          'Sprint Detail:',
          keyValueBlock(sprintKey),
          'Sprint Summary:',
          keyValueBlock(summaryKey),
        ),
      );
      widgets.add(pw.SizedBox(height: 8));
    }

    if (linesFor(teamKey).isNotEmpty) {
      widgets.add(_subSectionHeader(teamKey));
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: lineBlock(teamKey, fontSize: 9),
        ),
      );
      widgets.add(pw.SizedBox(height: 8));
    }

    if (linesFor(deliverablesKey).isNotEmpty) {
      widgets.add(_subSectionHeader(deliverablesKey));
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: lineBlock(deliverablesKey, fontSize: 8.5),
        ),
      );
      widgets.add(pw.SizedBox(height: 8));
    }

    if (widgets.isNotEmpty && widgets.last is pw.SizedBox) {
      widgets.removeLast();
    }
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

  String _sanitizeContentForPdf(String input) {
    var s = input;
    s = s.replaceAll('\u2192', '->');
    s = s.replaceAll('\u2190', '<-');
    s = s.replaceAll('\u2013', '-');
    s = s.replaceAll('\u2014', '-');
    s = s.replaceAll('\u2018', '\'');
    s = s.replaceAll('\u2019', '\'');
    s = s.replaceAll('\u201C', '"');
    s = s.replaceAll('\u201D', '"');
    s = s.replaceAll('\u2022', '-');
    s = s.replaceAll('\u00A0', ' ');
    return s;
  }

  String? _extractSprintIdFromContent(String content) {
    final sections = _parseReportSections(content);
    final sprintLines = sections['SPRINT'] ?? sections['SPRINT DETAIL'] ?? sections['SPRINT DETAIL:'] ?? const <String>[];
    for (final l in sprintLines) {
      final m = RegExp(r'^ID\s*:\s*(.+)$', caseSensitive: false).firstMatch(l.trim());
      if (m != null) {
        final v = (m.group(1) ?? '').trim();
        if (v.isNotEmpty) return v;
      }
    }
    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final t = lines[i].trim();
      if (t.toLowerCase().contains('sprint detail')) {
        for (var j = i + 1; j < lines.length && j < i + 12; j++) {
          final m = RegExp(r'^ID\s*:\s*(.+)$', caseSensitive: false)
              .firstMatch(lines[j].trim());
          if (m != null) {
            final v = (m.group(1) ?? '').trim();
            if (v.isNotEmpty) return v;
          }
        }
      }
    }
    for (final raw in content.split('\n')) {
      final line = raw.trim();
      final m = RegExp(r'^Sprint\s*ID\s*:\s*(.+)$', caseSensitive: false).firstMatch(line);
      if (m != null) {
        final v = (m.group(1) ?? '').trim();
        if (v.isNotEmpty) return v;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _enrichSprintReportWithProjectTotals(
      Map<String, dynamic> sprintReport) async {
    final sprint = sprintReport['sprint'] is Map
        ? Map<String, dynamic>.from(sprintReport['sprint'] as Map)
        : <String, dynamic>{};
    final project = sprintReport['project'] is Map
        ? Map<String, dynamic>.from(sprintReport['project'] as Map)
        : (sprint['project'] is Map
            ? Map<String, dynamic>.from(sprint['project'] as Map)
            : <String, dynamic>{});
    final projectId = (project['id'] ?? sprint['project_id'] ?? sprint['projectId'])?.toString();
    final projectKey = (project['key'] ?? sprint['project_key'] ?? sprint['projectKey'])?.toString();
    final key = '${projectId ?? ''}|${projectKey ?? ''}'.trim();
    if (key.isNotEmpty && _cachedProjectSprintTotalsKey == key && _cachedProjectSprintTotalsFuture != null) {
      final cached = await _cachedProjectSprintTotalsFuture!;
      return <String, dynamic>{
        ...sprintReport,
        'projectSprintTotals': cached,
      };
    }
    _cachedProjectSprintTotalsKey = key;
    _cachedProjectSprintTotalsFuture = _fetchProjectSprintTotals(projectId: projectId, projectKey: projectKey);
    final totals = await _cachedProjectSprintTotalsFuture!;
    return <String, dynamic>{
      ...sprintReport,
      'projectSprintTotals': totals,
    };
  }

  Future<Map<String, String>> _fetchProjectSprintTotals({String? projectId, String? projectKey}) async {
    final id = (projectId ?? '').trim();
    final key = (projectKey ?? '').trim();
    if (id.isEmpty && key.isEmpty) {
      return <String, String>{};
    }
    try {
      final query = <String, String>{'limit': '1000'};
      if (id.isNotEmpty) query['project_id'] = id;
      if (key.isNotEmpty) query['project_key'] = key;
      final resp = await _apiClient.get('/sprints', queryParams: query);
      if (!resp.isSuccess || resp.data == null) return <String, String>{};
      final raw = resp.data;
      List<dynamic> items = const [];
      if (raw is List) {
        items = raw;
      } else if (raw is Map) {
        final body = raw['data'] ?? raw['sprints'] ?? raw['items'] ?? raw;
        if (body is List) items = body;
        if (body is Map && body['data'] is List) items = body['data'] as List;
      }
      final sprints = items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      if (sprints.isEmpty) return <String, String>{};
      final total = sprints.length;
      final completed = sprints.where((s) {
        final st = (s['status'] ?? '').toString().toLowerCase();
        return st == 'completed' || st == 'done';
      }).length;
      final successRate = total == 0 ? 0 : ((completed / total) * 100).round();
      return <String, String>{
        'Total Sprints': total.toString(),
        'Completed Sprints': completed.toString(),
        'Sprint Success Rate': '$successRate%',
      };
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<String> _buildCanonicalSprintSignOffContentIfPossible(String originalContent) async {
    final normalized = _sanitizeContentForPdf(originalContent);
    final sprintId = _extractSprintIdFromContent(normalized);
    if (sprintId == null || sprintId.trim().isEmpty) return normalized;
    final sprintReport = await _fetchSprintReport(sprintId.trim());
    if (sprintReport == null) return normalized;
    final enriched = await _enrichSprintReportWithProjectTotals(sprintReport);
    final sprint = enriched['sprint'] is Map ? Map<String, dynamic>.from(enriched['sprint'] as Map) : <String, dynamic>{};
    final summary = enriched['summary'] is Map ? Map<String, dynamic>.from(enriched['summary'] as Map) : <String, dynamic>{};
    final project = enriched['project'] is Map
        ? Map<String, dynamic>.from(enriched['project'] as Map)
        : (sprint['project'] is Map ? Map<String, dynamic>.from(sprint['project'] as Map) : <String, dynamic>{});
    final totals = enriched['projectSprintTotals'] is Map
        ? Map<String, dynamic>.from(enriched['projectSprintTotals'] as Map)
        : <String, dynamic>{};
    final team = enriched['team'] is Map ? Map<String, dynamic>.from(enriched['team'] as Map) : <String, dynamic>{};
    final deliverables = enriched['deliverables'] is List
        ? (enriched['deliverables'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    String safe(dynamic v) => _sanitizeContentForPdf(v?.toString() ?? '').trim();
    String pick(List<String> values) {
      for (final v in values) {
        final t = v.trim();
        if (t.isNotEmpty && t != '-') return t;
      }
      return '-';
    }

    final signOffNotes = _buildSignOffNotesText(
      reportContent: normalized,
      clientComment: null,
      changeRequestDetails: null,
      status: ReportStatus.draft,
    );

    final b = StringBuffer();
    b.writeln('PROJECT');
    b.writeln('Name: ${pick([safe(project['name']), safe(sprint['project_name'])])}');
    b.writeln('Key: ${pick([safe(project['key']), safe(sprint['project_key'])])}');
    b.writeln('ID: ${pick([safe(project['id']), safe(sprint['project_id'])])}');
    b.writeln();
    b.writeln('PROJECT SPRINT TOTALS');
    b.writeln('Total Sprints: ${pick([safe(totals['Total Sprints']), safe(totals['total']), safe(totals['totalSprints']), safe(totals['total_sprints'])])}');
    b.writeln('Completed Sprints: ${pick([safe(totals['Completed Sprints']), safe(totals['completed']), safe(totals['completedSprints']), safe(totals['completed_sprints'])])}');
    b.writeln('Sprint Success Rate: ${pick([safe(totals['Sprint Success Rate']), safe(totals['successRate']), safe(totals['sprintSuccessRate']), safe(totals['success_rate'])])}');
    b.writeln();
    b.writeln('SPRINT');
    b.writeln('Name: ${pick([safe(sprint['name'])])}');
    b.writeln('ID: ${pick([safe(sprint['id'])])}');
    b.writeln('Status: ${pick([safe(sprint['status'])])}');
    b.writeln('Start: ${pick([safe(sprint['start_date']), safe(sprint['startDate'])])}');
    b.writeln('End: ${pick([safe(sprint['end_date']), safe(sprint['endDate'])])}');
    b.writeln();
    b.writeln('SPRINT SUMMARY');
    b.writeln('Total Deliverables: ${pick([safe(summary['total_deliverables']), safe(summary['totalDeliverables'])])}');
    b.writeln('Completed: ${pick([safe(summary['completed'])])}');
    b.writeln('In Progress: ${pick([safe(summary['in_progress']), safe(summary['inProgress'])])}');
    b.writeln('Not Started: ${pick([safe(summary['not_started']), safe(summary['notStarted'])])}');
    b.writeln('Overdue: ${pick([safe(summary['overdue'])])}');
    b.writeln('Blocked: ${pick([safe(summary['blocked'])])}');
    b.writeln('Sprint Progress: ${pick([safe(summary['sprint_progress']), safe(summary['sprintProgress']), safe(summary['progress'])])}');
    b.writeln('Completion Rate: ${pick([safe(summary['completion_rate']), safe(summary['completionRate'])])}');
    b.writeln('Health: ${pick([safe(summary['health'])])}');
    b.writeln();
    b.writeln('TEAM MEMBERS');
    final members = team['members'];
    if (members is List && members.isNotEmpty) {
      for (final m in members.whereType<Map>()) {
        final mm = Map<String, dynamic>.from(m);
        final name = safe(mm['name'] ?? mm['full_name'] ?? mm['fullName']);
        final email = safe(mm['email']);
        final role = safe(mm['role'] ?? mm['user_role'] ?? mm['userRole']);
        final parts = <String>[];
        if (name.isNotEmpty && name != '-') parts.add(name);
        if (email.isNotEmpty && email != '-') parts.add(email);
        if (role.isNotEmpty && role != '-') parts.add(role);
        b.writeln(parts.isEmpty ? '-' : parts.join(' | '));
      }
    } else {
      b.writeln('-');
    }
    b.writeln();
    b.writeln('DELIVERABLES');
    if (deliverables.isNotEmpty) {
      for (final d in deliverables) {
        final name = safe(d['name'] ?? d['title'] ?? d['deliverable_name'] ?? d['deliverableName']);
        final owner = safe(d['owner'] ?? d['owner_name'] ?? d['ownerName'] ?? d['assignee'] ?? d['assignee_name'] ?? d['assigneeName']);
        final status = safe(d['status'] ?? d['state']);
        final progress = safe(d['progress'] ?? d['percent_complete'] ?? d['percentComplete']);
        final due = safe(d['due_date'] ?? d['dueDate'] ?? d['due']);
        final completedAt = safe(d['completed_at'] ?? d['completedAt'] ?? d['completed']);
        final category = safe(d['category'] ?? d['type']);
        final overdue = safe(d['overdue']);
        final parts = <String>[];
        parts.add(name.isEmpty || name == '-' ? 'Deliverable' : name);
        if (owner.isNotEmpty && owner != '-') parts.add('Owner: $owner');
        if (status.isNotEmpty && status != '-') parts.add('Status: $status');
        if (progress.isNotEmpty && progress != '-') parts.add('Progress: $progress');
        if (due.isNotEmpty && due != '-') parts.add('Due: $due');
        if (completedAt.isNotEmpty && completedAt != '-') parts.add('Completed: $completedAt');
        if (category.isNotEmpty && category != '-') parts.add('Category: $category');
        if (overdue.isNotEmpty && overdue != '-') parts.add('Overdue: $overdue');
        b.writeln('- ${parts.join(' | ')}');
      }
    } else {
      b.writeln('-');
    }
    b.writeln();
    b.writeln('SIGN-OFF NOTES');
    b.writeln(signOffNotes.trim().isEmpty ? '-' : signOffNotes.trim());
    return b.toString().trim();
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
    bool includeHeader = true,
  }) {
    final name = preparedByName.trim().isEmpty ? '-' : preparedByName.trim();
    final role = (preparedByRole ?? '').trim();
    final hasSig = (signatureData ?? '').trim().isNotEmpty;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (includeHeader) _subSectionHeader('PREPARED BY'),
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
    bool includeHeader = true,
  }) {
    final name = reviewerName.trim().isEmpty ? '-' : reviewerName.trim();
    final role = (reviewerRole ?? '').trim();
    final hasSig = (signatureData ?? '').trim().isNotEmpty;
    final at = signedAt ?? DateTime.now();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (includeHeader) _subSectionHeader(label),
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

