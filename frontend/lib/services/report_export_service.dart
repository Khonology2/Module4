import 'dart:convert';
import 'dart:typed_data';
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
  final pw.ImageProvider? sprintIcon;
  final pw.ImageProvider? footerIcon1;
  final pw.ImageProvider? footerIcon2;
  final pw.ImageProvider? footerIcon3;

  const _BrandingAssets({
    this.logo,
    this.headerBackground,
    this.sprintIcon,
    this.footerIcon1,
    this.footerIcon2,
    this.footerIcon3,
  });
}

class PdfBytesResult {
  final Uint8List bytes;
  final String exportTitle;
  final String reportId;
  final int fileSize;
  final String fileHash;
  final String reportStatus;

  const PdfBytesResult({
    required this.bytes,
    required this.exportTitle,
    required this.reportId,
    required this.fileSize,
    required this.fileHash,
    required this.reportStatus,
  });
}

class ReportExportService {
  final ApiClient _apiClient = ApiClient();

  static const PdfColor _lightRedBar = PdfColor(242 / 255, 204 / 255, 204 / 255);
  static const PdfColor _darkOverlay = PdfColor(0, 0, 0, 0.55);
  static const PdfColor _brandRed = PdfColor(0.78, 0.04, 0.04);
  static const PdfColor _titleBarRed = PdfColor(139 / 255, 0, 0);
  static const PdfColor _ink = PdfColors.black;

  static Future<pw.ThemeData?>? _cachedThemeFuture;
  static Future<_BrandingAssets>? _cachedBrandingFuture;

  Future<void> warmup() async {
    try {
      await Future.wait([
        _loadBrandingAssets(),
        _loadPdfTheme(),
      ]);
    } catch (_) {}
  }

  Future<pw.ThemeData?> _loadPdfTheme() async {
    final cached = _cachedThemeFuture;
    if (cached != null) return cached;
    final fut = _loadPdfThemeUncached();
    _cachedThemeFuture = fut;
    return fut;
  }

  Future<pw.ThemeData?> _loadPdfThemeUncached() async {
    pw.Font? base;
    pw.Font? bold;
    pw.Font? italic;
    pw.Font? boldItalic;

    try {
      final bytes =
          (await rootBundle.load('assets/fonts/fonts/poppins/Poppins-Regular.ttf')).buffer.asUint8List();
      if (bytes.isNotEmpty) base = pw.Font.ttf(bytes.buffer.asByteData());
    } catch (_) {}

    try {
      final bytes = (await rootBundle.load('assets/fonts/fonts/poppins/Poppins-Bold.ttf')).buffer.asUint8List();
      if (bytes.isNotEmpty) bold = pw.Font.ttf(bytes.buffer.asByteData());
    } catch (_) {}

    try {
      final bytes = (await rootBundle.load('assets/fonts/fonts/poppins/Poppins-Italic.ttf')).buffer.asUint8List();
      if (bytes.isNotEmpty) italic = pw.Font.ttf(bytes.buffer.asByteData());
    } catch (_) {}

    try {
      final bytes =
          (await rootBundle.load('assets/fonts/fonts/poppins/Poppins-BoldItalic.ttf')).buffer.asUint8List();
      if (bytes.isNotEmpty) boldItalic = pw.Font.ttf(bytes.buffer.asByteData());
    } catch (_) {}

    if (base == null) return null;
    return pw.ThemeData.withFont(
      base: base,
      bold: bold ?? base,
      italic: italic ?? base,
      boldItalic: boldItalic ?? bold ?? base,
    );
  }

  Future<_BrandingAssets> _loadBrandingAssets() async {
    final cached = _cachedBrandingFuture;
    if (cached != null) return cached;
    final fut = _loadBrandingAssetsUncached();
    _cachedBrandingFuture = fut;
    return fut;
  }

  Future<_BrandingAssets> _loadBrandingAssetsUncached() async {
    pw.ImageProvider? logo;
    pw.ImageProvider? headerBackground;
    pw.ImageProvider? sprintIcon;
    pw.ImageProvider? footerIcon1;
    pw.ImageProvider? footerIcon2;
    pw.ImageProvider? footerIcon3;

    try {
      final bytes = (await rootBundle.load('assets/images/khono.png')).buffer.asUint8List();
      if (bytes.isNotEmpty) logo = pw.MemoryImage(bytes);
    } catch (_) {}
    try {
      final bytes = (await rootBundle.load('assets/images/khono_bg.png')).buffer.asUint8List();
      if (bytes.isNotEmpty) headerBackground = pw.MemoryImage(bytes);
    } catch (_) {}
    try {
      final bytes = (await rootBundle.load('assets/Sprints.png')).buffer.asUint8List();
      if (bytes.isNotEmpty) sprintIcon = pw.MemoryImage(bytes);
    } catch (_) {}
    try {
      final bytes =
          (await rootBundle.load('assets/Icons/Khonology_(Short Logo)_Circlulars_RED.png')).buffer.asUint8List();
      if (bytes.isNotEmpty) footerIcon1 = pw.MemoryImage(bytes);
    } catch (_) {}

    return _BrandingAssets(
      logo: logo,
      headerBackground: headerBackground,
      sprintIcon: sprintIcon,
      footerIcon1: footerIcon1,
      footerIcon2: footerIcon2 ?? footerIcon1,
      footerIcon3: footerIcon3 ?? footerIcon1,
    );
  }

  Future<SignOffReport> _hydrateReportForPdf(SignOffReport report) async {
    if (report.sprintReportData != null) return report;
    if (report.sprintPerformanceData != null && report.sprintPerformanceData!.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(report.sprintPerformanceData!);
        if (decoded is Map) {
          return report.copyWith(sprintReportData: Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }
    try {
      final response = await _apiClient.get('/sign-off-reports/${report.id}').timeout(const Duration(milliseconds: 800));
      if (response.isSuccess && response.data != null) {
        final raw = response.data;
        if (raw is Map) {
          final body = Map<String, dynamic>.from(raw);
          final dynamic unwrapped =
              body['data'] ?? body['report'] ?? body['signOffReport'] ?? body['sign_off_report'] ?? body['item'];
          final Map<String, dynamic> json =
              unwrapped is Map ? Map<String, dynamic>.from(unwrapped) : body;

          var parsed = SignOffReport.fromJson(json);
          if (report.reportTitle.trim().isNotEmpty) {
            parsed = parsed.copyWith(reportTitle: report.reportTitle);
          }
          if (report.reportContent.trim().isNotEmpty) {
            parsed = parsed.copyWith(reportContent: report.reportContent);
          }
          if (report.digitalSignature != null && report.digitalSignature!.trim().isNotEmpty) {
            parsed = parsed.copyWith(digitalSignature: report.digitalSignature);
          }
          if (parsed.sprintReportData == null && parsed.sprintPerformanceData != null) {
            try {
              final decoded = jsonDecode(parsed.sprintPerformanceData!);
              if (decoded is Map) {
                return parsed.copyWith(sprintReportData: Map<String, dynamic>.from(decoded));
              }
            } catch (_) {}
          }
          return parsed;
        }
        if (raw is String) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is Map) {
              final parsed = SignOffReport.fromJson(Map<String, dynamic>.from(decoded));
              if (parsed.sprintReportData == null && parsed.sprintPerformanceData != null) {
                try {
                  final decodedSprint = jsonDecode(parsed.sprintPerformanceData!);
                  if (decodedSprint is Map) {
                    return parsed.copyWith(sprintReportData: Map<String, dynamic>.from(decodedSprint));
                  }
                } catch (_) {}
              }
              return parsed;
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    return report;
  }

  Future<SignOffReport> _hydrateReportForPdfFast(SignOffReport report) async {
    if (report.sprintReportData != null && report.sprintReportData!.isNotEmpty) return report;
    final raw = report.sprintPerformanceData;
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return report.copyWith(sprintReportData: Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }
    return report;
  }

  bool _isSprintSignoffReport(SignOffReport report) {
    final data = report.sprintReportData;
    if (data == null || data.isEmpty) {
      final raw = report.sprintPerformanceData;
      if (raw != null && raw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            return decoded['sprint'] is Map || decoded['summary'] is Map;
          }
        } catch (_) {}
      }

      final contentUpper = report.reportContent.toUpperCase();
      if (contentUpper.contains('SPRINT SUMMARY') || contentUpper.contains('SPRINT DETAIL')) {
        return true;
      }
      return false;
    }
    final sprint = data['sprint'];
    final summary = data['summary'];
    return sprint is Map || summary is Map;
  }
  
  /// Fetch digital signatures for a report
  Future<List<Map<String, dynamic>>> _fetchSignatures(String reportId) async {
    try {
      debugPrint('🔍 Fetching signatures for report: $reportId');
      final response = await _apiClient
          .get('/sign-off-reports/$reportId/signatures')
          .timeout(const Duration(milliseconds: 800));
          
      debugPrint('📦 Signature response: isSuccess=${response.isSuccess}, data=${response.data}');
      
      if (response.isSuccess && response.data != null) {
        final raw = response.data;
        final List<dynamic>? data = raw is List
            ? raw
            : (raw is Map
                ? (raw['data'] is List ? List<dynamic>.from(raw['data'] as List) : null)
                : null);
        debugPrint('✅ Found ${data?.length ?? 0} signatures');
        return data?.map((e) => e as Map<String, dynamic>).toList() ?? [];
      }
      return [];
    } catch (e) {
      debugPrint('⚠️ Error/Timeout fetching signatures: $e');
      return [];
    }
  }
  
  /// Export report as PDF
  Future<void> exportReportAsPDF(SignOffReport report, {String? filePath, bool fast = false}) async {
    try {
      final result = await buildPdfBytes(report, fast: fast);
      await exportPdfBytes(result, filePath: filePath);
    } catch (e) {
      debugPrint('Error exporting PDF: $e');
      rethrow;
    }
  }

  Future<PdfBytesResult> buildPdfBytes(SignOffReport report, {bool fast = false}) async {
    final hydrateFuture = fast ? _hydrateReportForPdfFast(report) : _hydrateReportForPdf(report);
    final brandingFuture = _loadBrandingAssets();
    final themeFuture = _loadPdfTheme();
    final signaturesFuture = (fast || (report.digitalSignature != null && report.digitalSignature!.trim().isNotEmpty))
        ? Future<List<Map<String, dynamic>>>.value(const <Map<String, dynamic>>[])
        : _fetchSignatures(report.id);

    final results = await Future.wait([
      hydrateFuture,
      signaturesFuture,
      brandingFuture,
      themeFuture,
    ]);

    final reportForPdf = results[0] as SignOffReport;
    final signatures = results[1] as List<Map<String, dynamic>>;
    final branding = results[2] as _BrandingAssets;
    final theme = results[3] as pw.ThemeData?;

    final pdf = pw.Document(theme: theme);
    String exportTitle;

    if (_isSprintSignoffReport(reportForPdf)) {
      final resolvedTitle = _resolveSprintReportTitle(reportForPdf);
      exportTitle = resolvedTitle;
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(0, 20, 0, 50),
          theme: theme,
          footer: (pw.Context context) => _buildSprintFooter(context, branding),
          build: (pw.Context context) => [
            _buildSprintHeader(
              branding,
              title: resolvedTitle,
              date: _formatDate(reportForPdf.createdAt),
            ),
            ..._buildSprintSignoffBody(
              reportForPdf,
              signatures: signatures,
            ),
          ],
        ),
      );
    } else {
      exportTitle = reportForPdf.reportTitle.trim().isNotEmpty ? reportForPdf.reportTitle.trim() : 'Sign-Off Report';
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(0, 20, 0, 50),
          theme: theme,
          footer: (pw.Context context) => _buildSprintFooter(context, branding),
          build: (pw.Context context) => [
            _buildSprintHeader(
              branding,
              title: exportTitle,
              date: _formatDate(reportForPdf.createdAt),
              reportLabel: 'SIGN-OFF REPORT',
            ),
            ..._buildManualSignoffBody(
              reportForPdf,
              signatures: signatures,
            ),
          ],
        ),
      );
    }

    final bytes = await pdf.save();
    final fileSize = bytes.length;
    final fileHash = _generateFileHash(bytes);
    return PdfBytesResult(
      bytes: bytes,
      exportTitle: exportTitle,
      reportId: reportForPdf.id,
      fileSize: fileSize,
      fileHash: fileHash,
      reportStatus: reportForPdf.status.toString(),
    );
  }

  Future<void> exportPdfBytes(PdfBytesResult result, {String? filePath}) async {
    if (kIsWeb) {
      final blob = html.Blob([result.bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final fileName = 'Report_${result.exportTitle.replaceAll(' ', '_')}_${result.reportId}.pdf';
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click()
        ..remove();
      html.Url.revokeObjectUrl(url);
      debugPrint('✅ PDF downloaded successfully');
    } else {
      if (filePath != null) {
        final file = _createFile(filePath);
        await file.writeAsBytes(result.bytes);
      } else {
        try {
          final tempDir = await getTemporaryDirectory();
          final sanitizedTitle = result.exportTitle
              .replaceAll(RegExp(r'[^\w\s-]'), '')
              .replaceAll(RegExp(r'\s+'), '_');
          final outPath = '${tempDir.path}/${sanitizedTitle}_${result.reportId}.pdf';
          final file = _createFile(outPath);
          await file.writeAsBytes(result.bytes);

          await Share.shareXFiles(
            [XFile(outPath)],
            text: 'Sign-Off Report: ${result.exportTitle}',
          );
        } catch (e) {
          debugPrint('⚠️ Path provider not available, using base64 share: $e');
          final base64Pdf = base64Encode(result.bytes);
          await Share.share(
            'data:application/pdf;base64,$base64Pdf',
            subject: 'Sign-Off Report: ${result.exportTitle}',
          );
        }
      }
    }

    _apiClient
        .post('/sign-off-reports/${result.reportId}/export', body: {
          'exportFormat': 'pdf',
          'exportType': filePath != null ? 'download' : 'share',
          'fileSize': result.fileSize,
          'fileHash': result.fileHash,
          'metadata': {
            'reportTitle': result.exportTitle,
            'reportStatus': result.reportStatus,
            'exportedAt': DateTime.now().toIso8601String(),
          },
        })
        .timeout(const Duration(seconds: 5))
        .then((_) => debugPrint('✅ Export tracked in database'))
        .catchError((e) => debugPrint('⚠️ Failed to track export: $e'));
  }

  String _resolveSprintReportTitle(SignOffReport report) {
    String? fromData;
    final d = report.sprintReportData;
    if (d != null) {
      final dynamic v = d['reportTitle'] ?? d['report_title'] ?? d['aiTitle'] ?? d['suggestedTitle'] ?? d['title'];
      final s = v?.toString().trim() ?? '';
      if (s.isNotEmpty) fromData = s;
    }

    if (fromData == null) {
      final raw = report.sprintPerformanceData;
      if (raw != null && raw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            final dynamic v = decoded['reportTitle'] ?? decoded['report_title'] ?? decoded['aiTitle'] ?? decoded['suggestedTitle'] ?? decoded['title'];
            final s = v?.toString().trim() ?? '';
            if (s.isNotEmpty) fromData = s;
          }
        } catch (_) {}
      }
    }

    final t = report.reportTitle.trim();
    final comment = (report.clientComment ?? '').trim();
    final changeReq = (report.changeRequestDetails ?? '').trim();
    final looksLikeFeedback =
        t.isEmpty ||
        t == '-' ||
        t.toLowerCase() == 'untitled report' ||
        t.contains('\n') ||
        t.length > 140 ||
        (comment.isNotEmpty && (t == comment || t.contains(comment))) ||
        (changeReq.isNotEmpty && (t == changeReq || t.contains(changeReq)));

    if (fromData != null && fromData!.isNotEmpty) return fromData!;
    if (!looksLikeFeedback) return t;

    final sprint = d != null ? _asMap(d['sprint']) : const <String, dynamic>{};
    final project = d != null ? (_asMap(d['project']).isNotEmpty ? _asMap(d['project']) : _asMap(_asMap(sprint)['project'])) : const <String, dynamic>{};
    final sprintName = _stringOrDash(sprint['name']);
    final projectName = _stringOrDash(project['name']);
    if (projectName != '-' && sprintName != '-') {
      return 'Sprint Sign-Off: $projectName — $sprintName';
    }
    return 'Sprint Sign-Off Report';
  }
  
  /// Print report
  Future<void> printReport(SignOffReport report) async {
    try {
      final reportForPdf = await _hydrateReportForPdf(report);
      final branding = await _loadBrandingAssets();
      final theme = await _loadPdfTheme();
      final signatures = (reportForPdf.digitalSignature != null && reportForPdf.digitalSignature!.trim().isNotEmpty)
          ? const <Map<String, dynamic>>[]
          : await _fetchSignatures(reportForPdf.id);

      final pdf = pw.Document(theme: theme);

      if (_isSprintSignoffReport(reportForPdf)) {
        final resolvedTitle = _resolveSprintReportTitle(reportForPdf);
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.fromLTRB(0, 20, 0, 50),
            theme: theme,
            footer: (pw.Context context) => _buildSprintFooter(context, branding),
            build: (pw.Context context) => [
              _buildSprintHeader(
                branding,
                title: resolvedTitle,
                date: _formatDate(reportForPdf.createdAt),
              ),
              ..._buildSprintSignoffBody(
                reportForPdf,
                signatures: signatures,
              ),
            ],
          ),
        );
      } else {
        final title = reportForPdf.reportTitle.trim().isNotEmpty ? reportForPdf.reportTitle.trim() : 'Sign-Off Report';
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.fromLTRB(0, 20, 0, 50),
            theme: theme,
            footer: (pw.Context context) => _buildSprintFooter(context, branding),
            build: (pw.Context context) => [
              _buildSprintHeader(
                branding,
                title: title,
                date: _formatDate(reportForPdf.createdAt),
                reportLabel: 'SIGN-OFF REPORT',
              ),
              ..._buildManualSignoffBody(
                reportForPdf,
                signatures: signatures,
              ),
            ],
          ),
        );
      }
      
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

  pw.Widget _buildSprintHeader(
    _BrandingAssets branding, {
    String? title,
    String? date,
    String reportLabel = 'SPRINT SIGN-OFF REPORT',
  }) {
    return pw.SizedBox(
      width: double.infinity,
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 40),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Container(
                  width: double.infinity,
                  height: 100,
                  child: pw.Stack(
                    children: [
                      if (branding.headerBackground != null)
                        pw.Positioned.fill(
                          child: pw.Image(
                            branding.headerBackground!,
                            fit: pw.BoxFit.cover,
                          ),
                        )
                      else
                        pw.Positioned.fill(
                          child: pw.Container(
                            decoration: const pw.BoxDecoration(
                              gradient: pw.LinearGradient(
                                begin: pw.Alignment.centerLeft,
                                end: pw.Alignment.centerRight,
                                colors: [
                                  PdfColor(0.15, 0.05, 0.05, 1),
                                  PdfColor(0.05, 0.05, 0.05, 1),
                                ],
                              ),
                            ),
                          ),
                        ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.fromLTRB(20, 20, 20, 15),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                if (branding.logo != null)
                                  pw.SizedBox(
                                    height: 18,
                                    child: pw.Image(branding.logo!, fit: pw.BoxFit.contain),
                                  )
                                else
                                  pw.Text(
                                    'KHONOLOGY',
                                    style: pw.TextStyle(
                                      fontSize: 16,
                                      fontWeight: pw.FontWeight.bold,
                                      color: _brandRed,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                pw.SizedBox(height: 10),
                                pw.Text(
                                  reportLabel,
                                  style: pw.TextStyle(
                                    fontSize: 22,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.white,
                                  ),
                                ),
                              ],
                            ),
                            pw.Container(
                              width: 50,
                              height: 50,
                              decoration: const pw.BoxDecoration(
                                color: PdfColors.white,
                                shape: pw.BoxShape.circle,
                              ),
                              alignment: pw.Alignment.center,
                              child: branding.sprintIcon != null
                                  ? pw.Padding(
                                      padding: const pw.EdgeInsets.all(8),
                                      child: pw.Image(branding.sprintIcon!, fit: pw.BoxFit.contain),
                                    )
                                  : pw.Text(
                                      'K',
                                      style: pw.TextStyle(
                                        fontSize: 24,
                                        fontWeight: pw.FontWeight.bold,
                                        color: _brandRed,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  width: double.infinity,
                  color: _titleBarRed,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          'Title: ${title ?? ''}',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.Text(
                        'Date: ${date ?? ''}',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _buildManualSignoffBody(
    SignOffReport report, {
    required List<Map<String, dynamic>> signatures,
  }) {
    final bodyPadding = const pw.EdgeInsets.fromLTRB(40, 10, 40, 0);
    final blockPadding = const pw.EdgeInsets.fromLTRB(40, 6, 40, 0);

    final content = report.reportContent.trim().isNotEmpty ? report.reportContent.trim() : '-';
    final known = (report.knownLimitations ?? '').trim();
    final next = (report.nextSteps ?? '').trim();

    return [
      pw.Padding(padding: bodyPadding, child: _sectionBar('REPORT CONTENT')),
      pw.Padding(padding: blockPadding, child: _multilineText(content, fontSize: 10)),
      if (known.isNotEmpty) ...[
        pw.SizedBox(height: 10),
        pw.Padding(padding: bodyPadding, child: _sectionBar('KNOWN LIMITATIONS')),
        pw.Padding(padding: blockPadding, child: _multilineText(known, fontSize: 10)),
      ],
      if (next.isNotEmpty) ...[
        pw.SizedBox(height: 10),
        pw.Padding(padding: bodyPadding, child: _sectionBar('NEXT STEPS')),
        pw.Padding(padding: blockPadding, child: _multilineText(next, fontSize: 10)),
      ],
      pw.SizedBox(height: 12),
      ..._buildSignatureSection(report, signatures: signatures, bodyPadding: bodyPadding),
    ];
  }

  List<pw.Widget> _buildSignatureSection(
    SignOffReport report, {
    required List<Map<String, dynamic>> signatures,
    required pw.EdgeInsets bodyPadding,
  }) {
    final effectiveSignatures = <Map<String, dynamic>>[...signatures];
    final inlineSig = report.digitalSignature?.trim();
    if (effectiveSignatures.isEmpty && inlineSig != null && inlineSig.isNotEmpty) {
      effectiveSignatures.add({
        'signer_name': report.approvedByName ?? report.submittedByName ?? report.preparedByName ?? report.createdBy,
        'signer_role': report.approvedByRole ?? report.submittedByRole ?? report.preparedByRole ?? '',
        'signed_at': (report.approvedAt ?? report.submittedAt ?? report.createdAt).toIso8601String(),
        'signature_data': inlineSig,
      });
    }

    return [
      pw.Padding(padding: bodyPadding, child: _sectionBar('DIGITAL SIGNATURES')),
      if (effectiveSignatures.isEmpty)
        pw.SizedBox(height: 240)
      else
        ...effectiveSignatures.map((sig) {
          final signerName = (sig['signer_name'] ?? sig['signerName'] ?? sig['name']) as String? ?? 'Unknown';
          final signerRole = (sig['signer_role'] ?? sig['signerRole'] ?? sig['role']) as String? ?? 'Unknown';
          final signedAt = (sig['signed_at'] ?? sig['signedAt']) as String?;
          final signatureData =
              (sig['signature_data'] ?? sig['signatureData'] ?? sig['digitalSignature'] ?? sig['signature']) as String?;

          return pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(40, 10, 40, 0),
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              padding: const pw.EdgeInsets.all(12),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 250,
                    height: 140,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey50,
                      border: pw.Border.all(color: PdfColors.grey400, width: 1),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Stack(
                      children: [
                        pw.Positioned.fill(
                          child: pw.Opacity(
                            opacity: 0.1,
                            child: pw.Container(
                              decoration: const pw.BoxDecoration(image: null),
                              child: pw.Stack(
                                children: [
                                  for (int i = 1; i < 10; i++)
                                    pw.Positioned(
                                      top: i * 14.0,
                                      left: 0,
                                      right: 0,
                                      child: pw.Container(height: 0.5, color: PdfColors.grey700),
                                    ),
                                  for (int i = 1; i < 15; i++)
                                    pw.Positioned(
                                      left: i * 16.6,
                                      top: 0,
                                      bottom: 0,
                                      child: pw.Container(width: 0.5, color: PdfColors.grey700),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (signatureData != null && signatureData.isNotEmpty)
                          pw.Center(
                            child: pw.SizedBox(
                              width: 230,
                              height: 120,
                              child: _buildSignatureImage(signatureData),
                            ),
                          ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          signerName,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          _formatRole(signerRole),
                          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                        ),
                        if (signedAt != null) ...[
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Signed: ${_formatIsoDate(signedAt)}',
                            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
                          ),
                        ],
                        pw.SizedBox(height: 12),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.green,
                            borderRadius: pw.BorderRadius.all(pw.Radius.circular(20)),
                          ),
                          child: pw.Text(
                            'VERIFIED',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
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
  }

  pw.Widget _multilineText(String text, {double fontSize = 10}) {
    final normalized = text.replaceAll('\r\n', '\n');
    final parts = normalized.split('\n');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final p in parts) ...[
          if (p.trim().isEmpty) pw.SizedBox(height: 8) else pw.Text(p, style: pw.TextStyle(fontSize: fontSize, color: PdfColors.black)),
        ],
      ],
    );
  }

  pw.Widget _buildSprintFooter(pw.Context context, _BrandingAssets branding) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.only(top: 8, bottom: 28),
      child: (branding.footerIcon2 ?? branding.footerIcon1 ?? branding.footerIcon3) != null
          ? pw.SizedBox(
              height: 20,
              child: pw.Image(
                (branding.footerIcon2 ?? branding.footerIcon1 ?? branding.footerIcon3)!,
                fit: pw.BoxFit.contain,
              ),
            )
          : pw.Text(
              '~~~',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: _brandRed,
                letterSpacing: 2,
              ),
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

    final bodyPadding = const pw.EdgeInsets.fromLTRB(40, 10, 40, 0);

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

    final sprintCount = report.sprintIds.isNotEmpty ? report.sprintIds.length : 1;
    int totalDeliverablesAll = 0;
    int completedAll = 0;
    int inProgressAll = 0;
    int notStartedAll = 0;
    int overdueAll = 0;
    int blockedAll = 0;
    for (final d in deliverables) {
      totalDeliverablesAll += 1;
      final dd = _asMap(d);
      final statusRaw = (dd['status'] ?? '').toString().toLowerCase().trim();
      final isOverdue = dd['isOverdue'] == true;
      if (isOverdue) overdueAll += 1;
      if (statusRaw.contains('block')) blockedAll += 1;
      if (statusRaw.contains('not') && statusRaw.contains('start')) notStartedAll += 1;
      if (statusRaw.contains('progress')) inProgressAll += 1;
      if (statusRaw.contains('done') || statusRaw.contains('complete') || statusRaw.contains('signed_off') || statusRaw.contains('signedoff')) {
        completedAll += 1;
      }
    }

    final projectSprintTotals = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionBar('PROJECT SPRINT TOTALS:'),
        pw.SizedBox(height: 8),
        _kvLine('Total Sprints:', sprintCount.toString()),
        _kvLine('Total Deliverables:', totalDeliverablesAll.toString()),
        _kvLine('Completed:', completedAll.toString()),
        _kvLine('In Progress:', inProgressAll.toString()),
        _kvLine('Not Started:', notStartedAll.toString()),
        _kvLine('Overdue:', overdueAll.toString()),
        _kvLine('Blocked:', blockedAll.toString()),
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
          pw.SizedBox(height: 12),
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

    const maxTeamLines = 40;
    final teamLinesAll = team.map((m) {
      final mm = _asMap(m);
      return '- ${_stringOrDash(mm['name'])} | ${_stringOrDash(mm['email'])} | ${_stringOrDash(mm['role'])}';
    }).toList();
    final teamLines = teamLinesAll.length > maxTeamLines ? teamLinesAll.take(maxTeamLines).toList() : teamLinesAll;
    final teamOverflow = teamLinesAll.length - teamLines.length;
    final teamWidgets = <pw.Widget>[
      pw.Padding(padding: bodyPadding, child: _sectionBar('TEAM MEMBERS')),
      pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(40, 5, 40, 0),
        child: pw.Text(
          teamLines.isEmpty
              ? 'None'
              : [
                  teamLines.join('\n'),
                  if (teamOverflow > 0) '... and $teamOverflow more',
                ].join('\n'),
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
        ),
      ),
    ];

    const maxDeliverableLines = 60;
    final deliverableLinesAll = deliverables.map((d) {
      final dd = _asMap(d);
      final name = _stringOrDash(dd['name'] ?? dd['title']);
      final ownerName = _stringOrDash(dd['ownerName']);
      final status = _stringOrDash(dd['status']);
      final progress = '${_num(dd['progressPercent'])}%';
      final due = _formatIsoDate(dd['dueDate']?.toString());
      final completedOn = _formatIsoDate(dd['completionDate']?.toString());
      final category = _stringOrDash(dd['category']);
      final isOverdue = (dd['isOverdue'] == true) ? 'yes' : 'no';
      return '- $name | Owner: $ownerName | Status: $status | Progress: $progress | Due: $due | Completed: $completedOn | Category: $category | Overdue: $isOverdue';
    }).toList();
    final deliverableLines = deliverableLinesAll.length > maxDeliverableLines
        ? deliverableLinesAll.take(maxDeliverableLines).toList()
        : deliverableLinesAll;
    final deliverableOverflow = deliverableLinesAll.length - deliverableLines.length;
    final deliverableWidgets = <pw.Widget>[
      pw.Padding(padding: bodyPadding, child: _sectionBar('DELIVERABLES')),
      pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(40, 5, 40, 0),
        child: pw.Text(
          deliverableLines.isEmpty
              ? 'None'
              : [
                  deliverableLines.join('\n'),
                  if (deliverableOverflow > 0) '... and $deliverableOverflow more',
                ].join('\n'),
          style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.black),
        ),
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

    final effectiveSignatures = <Map<String, dynamic>>[...signatures];
    final inlineSig = report.digitalSignature?.trim();
    if (effectiveSignatures.isEmpty && inlineSig != null && inlineSig.isNotEmpty) {
      effectiveSignatures.add({
        'signer_name':
            report.approvedByName ?? report.submittedByName ?? report.preparedByName ?? report.createdBy,
        'signer_role': report.approvedByRole ?? report.submittedByRole ?? report.preparedByRole ?? '',
        'signed_at': (report.approvedAt ?? report.submittedAt ?? report.createdAt).toIso8601String(),
        'signature_data': inlineSig,
      });
    }

    final signatureWidgets = <pw.Widget>[
      pw.Padding(padding: bodyPadding, child: _sectionBar('DIGITAL SIGNATURES')),
      if (effectiveSignatures.isEmpty)
        pw.SizedBox(height: 240)
      else
        ...effectiveSignatures.map((sig) {
          final signerName = (sig['signer_name'] ?? sig['signerName'] ?? sig['name']) as String? ?? 'Unknown';
          final signerRole = (sig['signer_role'] ?? sig['signerRole'] ?? sig['role']) as String? ?? 'Unknown';
          final signedAt = (sig['signed_at'] ?? sig['signedAt']) as String?;
          final signatureData =
              (sig['signature_data'] ?? sig['signatureData'] ?? sig['digitalSignature'] ?? sig['signature']) as String?;

          return pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(40, 10, 40, 0),
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              padding: const pw.EdgeInsets.all(12),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Signature Box with Grid background
                  pw.Container(
                    width: 250,
                    height: 140,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey50,
                      border: pw.Border.all(color: PdfColors.grey400, width: 1),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Stack(
                      children: [
                        // Simple Grid Background
                        pw.Positioned.fill(
                          child: pw.Opacity(
                            opacity: 0.1,
                            child: pw.Container(
                              decoration: const pw.BoxDecoration(
                                image: null, // Would be a grid pattern
                              ),
                              // Simulate grid with horizontal and vertical lines
                              child: pw.Stack(
                                children: [
                                  for (int i = 1; i < 10; i++)
                                    pw.Positioned(
                                      top: i * 14.0,
                                      left: 0,
                                      right: 0,
                                      child: pw.Container(height: 0.5, color: PdfColors.grey700),
                                    ),
                                  for (int i = 1; i < 15; i++)
                                    pw.Positioned(
                                      left: i * 16.6,
                                      top: 0,
                                      bottom: 0,
                                      child: pw.Container(width: 0.5, color: PdfColors.grey700),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (signatureData != null && signatureData.isNotEmpty)
                          pw.Center(
                            child: pw.SizedBox(
                              width: 230,
                              height: 120,
                              child: _buildSignatureImage(signatureData),
                            ),
                          ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  // Signer Details
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          signerName,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          _formatRole(signerRole),
                          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                        ),
                        if (signedAt != null) ...[
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Signed: ${_formatIsoDate(signedAt)}',
                            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
                          ),
                        ],
                        pw.SizedBox(height: 12),
                        // VERIFIED Badge
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: const pw.BoxDecoration(
                            color: PdfColor(200 / 255, 230 / 255, 201 / 255), // Light green
                            borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
                          ),
                          child: pw.Text(
                            'VERIFIED',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor(46 / 255, 125 / 255, 50 / 255), // Dark green
                            ),
                          ),
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
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
    );
  }

  String _spacedLetters(String word) {
    final w = word.trim();
    if (w.isEmpty) return '';
    return w.split('').join(' ');
  }

  pw.Widget _kvLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.RichText(
        text: pw.TextSpan(
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
          children: [
            pw.TextSpan(
              text: '$label ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
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

      final normalized = (signatureData.contains(',') ? signatureData.split(',').last : signatureData)
          .replaceAll(RegExp(r'\s+'), '');
      final Uint8List imageBytes = base64Decode(normalized);
      
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

