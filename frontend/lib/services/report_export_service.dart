import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/sign_off_report.dart';
import 'api_client.dart';
import '../config/environment.dart';
import 'package:universal_html/html.dart' as html;

// Platform-specific imports (only import when not on web)
import 'dart:io' if (dart.library.html) '../services/file_stub.dart';
import 'package:path_provider/path_provider.dart' if (dart.library.html) '../services/path_provider_stub.dart';

class _BrandingAssets {
  final pw.ImageProvider? logo;
  final pw.ImageProvider? headerBackground;

  const _BrandingAssets({this.logo, this.headerBackground});
}

class ReportExportService {
  final ApiClient _apiClient = ApiClient();

  static const PdfColor _lightRedBar = PdfColor(242 / 255, 204 / 255, 204 / 255);
  static const PdfColor _darkOverlay = PdfColor(0, 0, 0, 0.55);
  static const PdfColor _brandRed = PdfColor(0.78, 0.04, 0.04);
  static const PdfColor _titleBarRed = PdfColor(0.60, 0.00, 0.00);
  static const PdfColor _ink = PdfColors.black;

  Future<_BrandingAssets> _loadBrandingAssets() async {
    pw.ImageProvider? logo;
    pw.ImageProvider? headerBackground;
    try {
      final bytes = (await rootBundle.load('assets/images/khono.png')).buffer.asUint8List();
      if (bytes.isNotEmpty) logo = pw.MemoryImage(bytes);
    } catch (_) {}
    try {
      final bytes = (await rootBundle.load('assets/images/khono_bg.png')).buffer.asUint8List();
      if (bytes.isNotEmpty) headerBackground = pw.MemoryImage(bytes);
    } catch (_) {}
    return _BrandingAssets(logo: logo, headerBackground: headerBackground);
  }

  Future<SignOffReport> _hydrateReportForPdf(SignOffReport report) async {
    if (report.sprintReportData != null) return report;
    try {
      final response = await _apiClient.get('/sign-off-reports/${report.id}');
      if (response.isSuccess && response.data is Map) {
        return SignOffReport.fromJson(Map<String, dynamic>.from(response.data as Map));
      }
    } catch (_) {}
    return report;
  }

  bool _isSprintSignoffReport(SignOffReport report) {
    final data = report.sprintReportData;
    if (data == null || data.isEmpty) return false;
    final sprint = data['sprint'];
    final summary = data['summary'];
    return sprint is Map || summary is Map;
  }
  
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
      final reportForPdf = await _hydrateReportForPdf(report);
      final signatures = await _fetchSignatures(reportForPdf.id);
      final branding = await _loadBrandingAssets();
      
      final pdf = pw.Document();

      if (_isSprintSignoffReport(reportForPdf)) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            header: (pw.Context context) => _buildSprintHeader(branding),
            footer: (pw.Context context) => _buildSprintFooter(context),
            build: (pw.Context context) => _buildSprintSignoffBody(
              reportForPdf,
              signatures: signatures,
            ),
          ),
        );
      } else {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(40),
            build: (pw.Context context) {
              return [
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
                        _formatDate(reportForPdf.createdAt),
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  reportForPdf.reportTitle,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  reportForPdf.reportContent,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ];
            },
          ),
        );
      }
      
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

  pw.Widget _buildSprintHeader(_BrandingAssets branding) {
    return pw.Container(
      width: double.infinity,
      height: 92,
      child: pw.Stack(
        children: [
          if (branding.headerBackground != null)
            pw.Positioned.fill(
              child: pw.Image(
                branding.headerBackground!,
                fit: pw.BoxFit.cover,
              ),
            ),
          pw.Positioned.fill(child: pw.Container(color: _darkOverlay)),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(40, 18, 40, 16),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      Environment.appName.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: _brandRed,
                        letterSpacing: 2,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'SPRINT SIGN-OFF REPORT',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
                if (branding.logo != null)
                  pw.Container(
                    width: 34,
                    height: 34,
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.white,
                      shape: pw.BoxShape.circle,
                    ),
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Image(branding.logo!, fit: pw.BoxFit.contain),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSprintFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(40, 10, 40, 18),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            Environment.appName,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _buildSprintSignoffBody(
    SignOffReport report, {
    required List<Map<String, dynamic>> signatures,
  }) {
    final data = report.sprintReportData ?? const <String, dynamic>{};
    final sprint = _asMap(data['sprint']);
    final summary = _asMap(data['summary']);
    final projectFromData = _asMap(data['project']);
    final project = projectFromData.isNotEmpty ? projectFromData : _asMap(sprint['project']);
    final team = _asList(_asMap(data['team'])['members']);
    final deliverables = _asList(data['deliverables']);

    final sprintName = _stringOrDash(sprint['name']);
    final sprintId = _stringOrDash(sprint['id']);
    final sprintStatus = _stringOrDash(sprint['status']);
    final sprintStart = _formatIsoDate(sprint['startDate']?.toString());
    final sprintEnd = _formatIsoDate(sprint['endDate']?.toString());

    final projectName = _stringOrDash(project['name']);
    final projectKey = _stringOrDash(project['key']);
    final projectId = _stringOrDash(project['id']);

    final totalDeliverables = _stringOrDash(summary['totalDeliverables']);
    final completed = _stringOrDash(summary['completedDeliverables']);
    final inProgress = _stringOrDash(summary['inProgressDeliverables']);
    final notStarted = _stringOrDash(summary['notStartedDeliverables']);
    final overdue = _stringOrDash(summary['overdueDeliverables']);
    final blocked = _stringOrDash(summary['blockedDeliverables']);
    final sprintProgress = '${_num(summary['sprintProgressPercent'])}%';
    final completionRate = '${_num(summary['completionRatePercent'])}%';
    final health = _stringOrDash(summary['health']).toUpperCase();
    final incomplete = _stringOrDash(summary['incompleteDeliverables']);

    final note = _extractReportSection(report.reportContent, 'SIGN-OFF NOTES') ?? '-';
    final feedback = _extractReportSection(report.reportContent, 'FEEDBACK');

    final bodyPadding = const pw.EdgeInsets.fromLTRB(40, 16, 40, 0);
    final titleBar = pw.Container(
      width: double.infinity,
      color: _titleBarRed,
      padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Title: ${report.reportTitle}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
          ),
          pw.Text(
            'Date: ${_formatDate(report.createdAt)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
          ),
        ],
      ),
    );

    final projectDetail = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionBar('PROJECT DETAIL:'),
        pw.SizedBox(height: 8),
        _kvLine('Name:', projectName),
        _kvLine('Key:', projectKey),
        _kvLine('ID:', projectId),
      ],
    );

    final projectSprintTotals = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionBar('PROJECT SPRINT TOTALS:'),
        pw.SizedBox(height: 8),
        _kvLine('Total Deliverables:', totalDeliverables),
        _kvLine('Completed:', completed),
        _kvLine('Incomplete:', incomplete),
        _kvLine('Sprint Progress:', sprintProgress),
        _kvLine('Completion Rate:', completionRate),
      ],
    );

    final sprintDetail = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionBar('SPRINT DETAIL:'),
        pw.SizedBox(height: 8),
        _kvLine('Name:', sprintName),
        _kvLine('ID:', sprintId),
        _kvLine('Status:', sprintStatus),
        _kvLine('Start:', sprintStart),
        _kvLine('End:', sprintEnd),
      ],
    );

    final sprintSummary = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionBar('SPRINT SUMMARY:'),
        pw.SizedBox(height: 8),
        _kvLine('Total Deliverables:', totalDeliverables),
        _kvLine('Completed:', completed),
        _kvLine('In Progress:', inProgress),
        _kvLine('Not Started:', notStarted),
        _kvLine('Overdue:', overdue),
        _kvLine('Blocked:', blocked),
        _kvLine('Sprint Progress:', sprintProgress),
        _kvLine('Completion Rate:', completionRate),
        _kvLine('Health:', health),
      ],
    );

    final topRows = pw.Padding(
      padding: bodyPadding,
      child: pw.Column(
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: projectDetail),
              pw.SizedBox(width: 16),
              pw.Expanded(child: projectSprintTotals),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: sprintDetail),
              pw.SizedBox(width: 16),
              pw.Expanded(child: sprintSummary),
            ],
          ),
        ],
      ),
    );

    final teamWidgets = <pw.Widget>[
      pw.Padding(padding: bodyPadding, child: _sectionBar('TEAM MEMBERS')),
      ...team.map((m) {
        final mm = _asMap(m);
        final line = '- ${_stringOrDash(mm['name'])} | ${_stringOrDash(mm['email'])} | ${_stringOrDash(mm['role'])}';
        return pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(40, 4, 40, 0),
          child: pw.Text(line, style: const pw.TextStyle(fontSize: 9, color: PdfColors.black)),
        );
      }),
      if (team.isEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(40, 4, 40, 0),
          child: pw.Text('None', style: const pw.TextStyle(fontSize: 9, color: PdfColors.black)),
        ),
    ];

    final deliverableWidgets = <pw.Widget>[
      pw.Padding(padding: bodyPadding, child: _sectionBar('DELIVERABLES')),
      ...deliverables.map((d) {
        final dd = _asMap(d);
        final name = _stringOrDash(dd['name'] ?? dd['title']);
        final ownerName = _stringOrDash(dd['ownerName']);
        final status = _stringOrDash(dd['status']);
        final progress = '${_num(dd['progressPercent'])}%';
        final due = _formatIsoDate(dd['dueDate']?.toString());
        final completedOn = _formatIsoDate(dd['completionDate']?.toString());
        final category = _stringOrDash(dd['category']);
        final isOverdue = (dd['isOverdue'] == true) ? 'yes' : 'no';
        final line =
            '- $name | Owner: $ownerName | Status: $status | Progress: $progress | Due: $due | Completed: $completedOn | Category: $category | Overdue: $isOverdue';
        return pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(40, 4, 40, 0),
          child: pw.Text(line, style: const pw.TextStyle(fontSize: 8.8, color: PdfColors.black)),
        );
      }),
      if (deliverables.isEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(40, 4, 40, 0),
          child: pw.Text('None', style: const pw.TextStyle(fontSize: 9, color: PdfColors.black)),
        ),
    ];

    final notesWidgets = <pw.Widget>[
      pw.Padding(padding: bodyPadding, child: _sectionBar('SIGN-OFF NOTES')),
      pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(40, 6, 40, 0),
        child: pw.Text(
          note.trim().isEmpty ? '-' : note.trim(),
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
        ),
      ),
      if (feedback != null && feedback.trim().isNotEmpty && feedback.trim() != '-')
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(40, 6, 40, 0),
          child: pw.Text(
            'Feedback: ${feedback.trim()}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
          ),
        ),
    ];

    final signatureWidgets = <pw.Widget>[
      pw.Padding(padding: bodyPadding, child: _sectionBar('DIGITAL SIGNATURES')),
      if (signatures.isEmpty)
        pw.SizedBox(height: 20)
      else
        ...signatures.map((sig) {
          final signerName = sig['signer_name'] as String? ?? 'Unknown';
          final signerRole = sig['signer_role'] as String? ?? 'Unknown';
          final signedAt = sig['signed_at'] as String?;
          final signatureData = sig['signature_data'] as String?;
          final signatureHash = sig['signature_hash'] as String? ?? '';

          return pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(40, 10, 40, 0),
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (signatureData != null && signatureData.isNotEmpty)
                    pw.Container(
                      width: 150,
                      height: 60,
                      margin: const pw.EdgeInsets.only(right: 12),
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
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          signerName,
                          style: pw.TextStyle(
                            fontSize: 11.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          _formatRole(signerRole),
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                        ),
                        if (signedAt != null) ...[
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'Signed: ${_formatDateTime(signedAt)}',
                            style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey600),
                          ),
                        ],
                        pw.SizedBox(height: 6),
                        pw.Text(
                          signatureHash.isNotEmpty
                              ? 'Hash: ${signatureHash.substring(0, signatureHash.length > 16 ? 16 : signatureHash.length)}...'
                              : 'Hash: -',
                          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
    ];

    return [
      titleBar,
      topRows,
      ...teamWidgets,
      pw.SizedBox(height: 8),
      ...deliverableWidgets,
      pw.SizedBox(height: 8),
      ...notesWidgets,
      pw.SizedBox(height: 8),
      ...signatureWidgets,
      pw.SizedBox(height: 10),
    ];
  }

  pw.Widget _sectionBar(String title) {
    return pw.Container(
      width: double.infinity,
      color: _lightRedBar,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
    );
  }

  pw.Widget _kvLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        text: pw.TextSpan(
          style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.black),
          children: [
            pw.TextSpan(text: '$label '),
            pw.TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    return const <dynamic>[];
  }

  String _stringOrDash(dynamic value) {
    final s = value == null ? '' : value.toString().trim();
    return s.isEmpty ? '-' : s;
  }

  int _num(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.round();
    final s = value == null ? '' : value.toString();
    final n = double.tryParse(s);
    return n == null ? 0 : n.round();
  }

  String _formatIsoDate(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '-';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso.length >= 10 ? iso.substring(0, 10) : iso;
    }
  }

  String? _extractReportSection(String reportContent, String sectionTitle) {
    final lines = reportContent.split('\n');
    final needle = sectionTitle.trim().toUpperCase();
    int start = -1;
    for (int i = 0; i < lines.length; i += 1) {
      final t = lines[i].trim().toUpperCase();
      if (t == needle) {
        start = i + 1;
        break;
      }
    }
    if (start < 0 || start >= lines.length) return null;
    int end = lines.length;
    for (int i = start; i < lines.length; i += 1) {
      final t = lines[i].trim();
      final upper = t.toUpperCase();
      if (t.isNotEmpty && t == upper && upper.length >= 3) {
        end = i;
        break;
      }
    }
    final out = lines.sublist(start, end).join('\n').trim();
    return out.isEmpty ? null : out;
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

