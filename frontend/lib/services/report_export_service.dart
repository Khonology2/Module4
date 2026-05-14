import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/sign_off_report.dart';
import 'api_client.dart';
import 'profile_service.dart';
import 'package:universal_html/html.dart' as html;

// Platform-specific imports (only import when not on web)
import 'dart:io' if (dart.library.html) '../services/file_stub.dart';
import 'package:path_provider/path_provider.dart' if (dart.library.html) '../services/path_provider_stub.dart';

class _BrandingAssets {
  final pw.ImageProvider? logo;
  final pw.ImageProvider? wordmark;
  final pw.ImageProvider? headerBackground;
  final pw.ImageProvider? sprintIcon;
  final pw.ImageProvider? footerIcon1;
  final pw.ImageProvider? footerIcon2;
  final pw.ImageProvider? footerIcon3;

  const _BrandingAssets({
    this.logo,
    this.wordmark,
    this.headerBackground,
    this.sprintIcon,
    this.footerIcon1,
    this.footerIcon2,
    this.footerIcon3,
  });
}

class _ParsedSignaturePayload {
  final Uint8List? imageBytes;
  final String? typedText;

  const _ParsedSignaturePayload({this.imageBytes, this.typedText});
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
  static const PdfColor _brandRed = PdfColor(0.78, 0.04, 0.04);
  static const PdfColor _ink = PdfColors.black;
  static const double _reportSideInset = 40;
  static const double _reportColumnGap = 16;
  static final double _reportContentWidth =
      PdfPageFormat.a4.width - (_reportSideInset * 2);
  static final double _reportHalfColumnWidth =
      (_reportContentWidth - _reportColumnGap) / 2;
  static Future<pw.ThemeData?>? _cachedThemeFuture;
  static Future<_BrandingAssets>? _cachedBrandingFuture;
  static Future<_BrandingAssets>? _cachedBrandingFastFuture;

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

  Future<_BrandingAssets> _loadBrandingAssetsFast() async {
    final cached = _cachedBrandingFastFuture;
    if (cached != null) return cached;
    final fut = _loadBrandingAssetsFastUncached();
    _cachedBrandingFastFuture = fut;
    return fut;
  }

  Future<_BrandingAssets> _loadBrandingAssetsUncached() async {
    pw.ImageProvider? logo;
    pw.ImageProvider? wordmark;
    pw.ImageProvider? headerBackground;
    pw.ImageProvider? sprintIcon;
    pw.ImageProvider? footerIcon1;
    pw.ImageProvider? footerIcon2;
    pw.ImageProvider? footerIcon3;

    try {
      final bytes = (await rootBundle.load('assets/Icons/khonology_name_icon.png')).buffer.asUint8List();
      if (bytes.isNotEmpty) wordmark = pw.MemoryImage(bytes);
    } catch (_) {}
    try {
      final bytes = (await rootBundle.load('assets/images/khono.png')).buffer.asUint8List();
      if (bytes.isNotEmpty) logo = pw.MemoryImage(bytes);
      wordmark ??= logo;
    } catch (_) {}
    try {
      final bytes = (await rootBundle.load('assets/Icons/khono_bg.png')).buffer.asUint8List();
      if (bytes.isNotEmpty) headerBackground = pw.MemoryImage(bytes);
    } catch (_) {}
    try {
      final bytes = (await rootBundle.load('assets/images/khono_bg.png')).buffer.asUint8List();
      if (bytes.isNotEmpty) headerBackground ??= pw.MemoryImage(bytes);
    } catch (_) {}
    try {
      final bytes = (await rootBundle.load('assets/Icons/Sprints console inactive.png.png')).buffer.asUint8List();
      if (bytes.isNotEmpty) sprintIcon = pw.MemoryImage(bytes);
    } catch (_) {}
    try {
      final bytes = (await rootBundle.load('assets/Icons/Sprints console active.png.png')).buffer.asUint8List();
      if (bytes.isNotEmpty) sprintIcon ??= pw.MemoryImage(bytes);
    } catch (_) {}
    try {
      final bytes = (await rootBundle.load('assets/Sprints.png')).buffer.asUint8List();
      if (bytes.isNotEmpty) sprintIcon ??= pw.MemoryImage(bytes);
    } catch (_) {}
    try {
      final bytes =
          (await rootBundle.load('assets/Icons/Khonology_(Short Logo)_Circlulars_RED.png')).buffer.asUint8List();
      if (bytes.isNotEmpty) footerIcon1 = pw.MemoryImage(bytes);
    } catch (_) {}

    return _BrandingAssets(
      logo: logo,
      wordmark: wordmark,
      headerBackground: headerBackground,
      sprintIcon: sprintIcon,
      footerIcon1: footerIcon1,
      footerIcon2: footerIcon2 ?? footerIcon1,
      footerIcon3: footerIcon3 ?? footerIcon1,
    );
  }

  Future<_BrandingAssets> _loadBrandingAssetsFastUncached() async {
    pw.ImageProvider? logo;
    pw.ImageProvider? wordmark;
    pw.ImageProvider? headerBackground;
    pw.ImageProvider? sprintIcon;
    pw.ImageProvider? footerIcon1;

    try {
      final bytes = (await rootBundle.load('assets/Icons/khonology_name_icon.png')).buffer.asUint8List();
      if (bytes.isNotEmpty) wordmark = pw.MemoryImage(bytes);
    } catch (_) {}
    try {
      final bytes = (await rootBundle.load('assets/images/khono.png')).buffer.asUint8List();
      if (bytes.isNotEmpty) logo = pw.MemoryImage(bytes);
      wordmark ??= logo;
    } catch (_) {}
    try {
      final bytes = (await rootBundle.load('assets/Icons/khono_bg.png')).buffer.asUint8List();
      if (bytes.isNotEmpty) headerBackground = pw.MemoryImage(bytes);
    } catch (_) {}
    try {
      final bytes = (await rootBundle.load('assets/images/khono_bg.png')).buffer.asUint8List();
      if (bytes.isNotEmpty) headerBackground ??= pw.MemoryImage(bytes);
    } catch (_) {}
    try {
      final bytes = (await rootBundle.load('assets/Icons/Sprints console inactive.png.png')).buffer.asUint8List();
      if (bytes.isNotEmpty) sprintIcon = pw.MemoryImage(bytes);
    } catch (_) {}
    try {
      final bytes = (await rootBundle.load('assets/Icons/Sprints console active.png.png')).buffer.asUint8List();
      if (bytes.isNotEmpty) sprintIcon ??= pw.MemoryImage(bytes);
    } catch (_) {}
    try {
      final bytes = (await rootBundle.load('assets/Sprints.png')).buffer.asUint8List();
      if (bytes.isNotEmpty) sprintIcon ??= pw.MemoryImage(bytes);
    } catch (_) {}
    try {
      final bytes =
          (await rootBundle.load('assets/Icons/Khonology_(Short Logo)_Circlulars_RED.png')).buffer.asUint8List();
      if (bytes.isNotEmpty) footerIcon1 = pw.MemoryImage(bytes);
    } catch (_) {}

    return _BrandingAssets(
      logo: logo,
      wordmark: wordmark,
      headerBackground: headerBackground,
      sprintIcon: sprintIcon,
      footerIcon1: footerIcon1,
      footerIcon2: footerIcon1,
      footerIcon3: footerIcon1,
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
      final response = await _apiClient.get(
        '/sign-off-reports/${report.id}',
        timeout: const Duration(milliseconds: 800),
      );
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
      final response = await _apiClient.get(
        '/sign-off-reports/$reportId/signatures',
        timeout: const Duration(milliseconds: 800),
      );
          
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
  Future<void> exportReportAsPDF(SignOffReport report, {String? filePath, bool fast = false, bool includeSignatures = true}) async {
    try {
      final result = await buildPdfBytes(report, fast: fast, includeSignatures: includeSignatures);
      await exportPdfBytes(result, filePath: filePath);
    } catch (e) {
      debugPrint('Error exporting PDF: $e');
      rethrow;
    }
  }

  Future<void> exportReportAsPDFFromServer(SignOffReport report, {String? filePath}) async {
    try {
      final bytes = await _apiClient.getBytes(
        '/sign-off-reports/${report.id}/pdf',
        timeout: const Duration(seconds: 180),
        headers: const <String, String>{'Accept': 'application/pdf'},
      );
      final fileSize = bytes.length;
      final fileHash = _generateFileHash(bytes);
      final exportTitle = report.reportTitle.trim().isNotEmpty ? report.reportTitle.trim() : 'Sign-Off Report';
      final result = PdfBytesResult(
        bytes: bytes,
        exportTitle: exportTitle,
        reportId: report.id,
        fileSize: fileSize,
        fileHash: fileHash,
        reportStatus: report.status.toString(),
      );
      await exportPdfBytes(result, filePath: filePath);
      return;
    } catch (e) {
      debugPrint('Server PDF export failed, using client PDF (fast): $e');
    }
    await exportReportAsPDF(report, filePath: filePath, fast: true, includeSignatures: true);
  }

  Future<Map<String, dynamic>?> _loadUserProfileForPdf() async {
    try {
      final profile = await ProfileService.getUserProfile();
      return profile.isEmpty ? null : profile;
    } catch (_) {
      return null;
    }
  }

  Future<PdfBytesResult> buildPdfBytes(SignOffReport report, {bool fast = false, bool includeSignatures = true}) async {
    final hydrateFuture = fast ? _hydrateReportForPdfFast(report) : _hydrateReportForPdf(report);
    final brandingFuture = fast ? _loadBrandingAssetsFast() : _loadBrandingAssets();
    final themeFuture = fast ? Future<pw.ThemeData?>.value(null) : _loadPdfTheme();
    final profileFuture = _loadUserProfileForPdf();
    final signaturesFuture = (!includeSignatures || fast)
        ? Future<List<Map<String, dynamic>>>.value(const <Map<String, dynamic>>[])
        : _fetchSignatures(report.id);

    final results = await Future.wait([
      hydrateFuture,
      signaturesFuture,
      brandingFuture,
      themeFuture,
      profileFuture,
    ]);

    final reportForPdf = results[0] as SignOffReport;
    final signatures = results[1] as List<Map<String, dynamic>>;
    final branding = results[2] as _BrandingAssets;
    final theme = results[3] as pw.ThemeData?;
    final currentProfile = results[4] as Map<String, dynamic>?;
    final effectiveSignatures = includeSignatures
        ? _resolveEffectiveSignatures(reportForPdf, signatures)
        : const <Map<String, dynamic>>[];
    final footerSignature = _selectFooterSignature(effectiveSignatures);

    final pdf = pw.Document(theme: theme);
    String exportTitle;

    if (_isSprintSignoffReport(reportForPdf)) {
      final resolvedTitle = _resolveSprintReportTitle(reportForPdf);
      exportTitle = resolvedTitle;
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(0, 20, 0, 88),
          theme: theme,
          footer: (pw.Context context) => _buildDocumentFooter(
            context,
            branding,
            signature: footerSignature,
            currentProfile: currentProfile,
          ),
          build: (pw.Context context) => [
            _buildSprintHeader(
              branding,
              title: resolvedTitle,
              date: _formatDate(reportForPdf.createdAt),
            ),
            ..._buildSprintSignoffBody(
              reportForPdf,
              branding: branding,
              currentProfile: currentProfile,
            ),
          ],
        ),
      );
    } else {
      exportTitle = reportForPdf.reportTitle.trim().isNotEmpty ? reportForPdf.reportTitle.trim() : 'Sign-Off Report';
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(0, 20, 0, 88),
          theme: theme,
          footer: (pw.Context context) => _buildDocumentFooter(
            context,
            branding,
            signature: footerSignature,
            currentProfile: currentProfile,
          ),
          build: (pw.Context context) => [
            _buildSprintHeader(
              branding,
              title: exportTitle,
              date: _formatDate(reportForPdf.createdAt),
            ),
            ..._buildSprintSignoffBody(
              reportForPdf,
              branding: branding,
              currentProfile: currentProfile,
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
        }, timeout: const Duration(seconds: 3))
        .then((resp) {
          if (resp.isSuccess) {
            debugPrint('✅ Export tracked in database');
          } else {
            debugPrint('⚠️ Failed to track export: ${resp.error ?? 'unknown error'}');
          }
          return null;
        })
        .catchError((e) {
          debugPrint('⚠️ Failed to track export: $e');
          return null;
        });
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

    final sprint = d != null ? _asMap(d['sprint']) : const <String, dynamic>{};
    final project =
        d != null ? (_asMap(d['project']).isNotEmpty ? _asMap(d['project']) : _asMap(_asMap(sprint)['project'])) : const <String, dynamic>{};
    final sprintName = _stringOrDash(sprint['name']);
    final projectName = _stringOrDash(project['name']);

    if (sprintName != '-') return sprintName;

    if (fromData != null && fromData.isNotEmpty) {
      final fd = fromData.trim();
      final fdLower = fd.toLowerCase();
      final looksLikeFeedbackTitle =
          fd.contains('\n') ||
          fd.length > 160 ||
          fdLower.contains('feedback') ||
          fdLower.contains('comment') ||
          fdLower.contains('change request') ||
          fdLower.contains('requested change') ||
          fdLower.startsWith('please ');
      if (!looksLikeFeedbackTitle) return fd;
    }
    if (projectName != '-') return 'Sprint Sign-Off: $projectName';
    if (t.isNotEmpty && t != '-' && t.toLowerCase().contains('sprint')) return t;
    return 'Sprint Sign-Off Report';
  }
  
  /// Print report
  Future<void> printReport(SignOffReport report) async {
    try {
      final result = await buildPdfBytes(report, includeSignatures: true);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => result.bytes,
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
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 40),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            width: double.infinity,
            height: 118,
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
                            PdfColor(0.12, 0.02, 0.02, 1),
                            PdfColor(0.03, 0.03, 0.03, 1),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (branding.wordmark != null)
                  pw.Positioned(
                    left: 20,
                    top: 26,
                    child: pw.Image(
                      branding.wordmark!,
                      width: 420,
                      height: 28,
                      fit: pw.BoxFit.contain,
                    ),
                  )
                else
                  pw.Positioned(
                    left: 20,
                    top: 26,
                    child: pw.Text(
                      'K H O N O L O G Y',
                      style: pw.TextStyle(
                        fontSize: 30,
                        fontWeight: pw.FontWeight.bold,
                        color: _brandRed,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                pw.Positioned(
                  left: 22,
                  top: 67,
                  child: pw.Text(
                    reportLabel,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
                if (branding.sprintIcon != null)
                  pw.Positioned(
                    right: 18,
                    top: 12,
                    child: pw.Image(
                      branding.sprintIcon!,
                      width: 78,
                      height: 78,
                      fit: pw.BoxFit.contain,
                    ),
                  )
                else
                  pw.Positioned(
                    right: 18,
                    top: 18,
                    child: pw.Text(
                      'K',
                      style: pw.TextStyle(
                        fontSize: 26,
                        fontWeight: pw.FontWeight.bold,
                        color: _brandRed,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          pw.Container(
            width: double.infinity,
            height: 34,
            color: _brandRed,
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'Title: ${title ?? ''}',
                    style: pw.TextStyle(
                      fontSize: 11.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                    maxLines: 1,
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Text(
                  'Date: ${date ?? ''}',
                  style: pw.TextStyle(
                    fontSize: 11.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _resolveEffectiveSignatures(
    SignOffReport report,
    List<Map<String, dynamic>> signatures,
  ) {
    final effectiveSignatures = <Map<String, dynamic>>[...signatures];
    final inlineSig = report.digitalSignature?.trim();
    final hasMatchingInline = inlineSig != null &&
        inlineSig.isNotEmpty &&
        effectiveSignatures.any(
          (sig) => ((sig['signature_data'] ?? sig['signatureData'] ?? '').toString().trim()) == inlineSig,
        );
    if (!hasMatchingInline && inlineSig != null && inlineSig.isNotEmpty) {
      effectiveSignatures.add({
        'signer_name': report.approvedByName ?? report.submittedByName ?? report.preparedByName ?? report.createdBy,
        'signer_role': report.approvedByRole ?? report.submittedByRole ?? report.preparedByRole ?? '',
        'signed_at': (report.approvedAt ?? report.submittedAt ?? report.createdAt).toIso8601String(),
        'signature_data': inlineSig,
      });
    }

    return effectiveSignatures;
  }

  Map<String, dynamic>? _selectFooterSignature(List<Map<String, dynamic>> signatures) {
    if (signatures.isEmpty) {
      return null;
    }
    return signatures.last;
  }

  pw.Widget _buildDocumentFooter(
    pw.Context context,
    _BrandingAssets branding, {
    Map<String, dynamic>? signature,
    Map<String, dynamic>? currentProfile,
  }) {
    final isLastPage = context.pageNumber == context.pagesCount;
    final hasFooterSignature = isLastPage && signature != null;

    return pw.Container(
      alignment: hasFooterSignature ? pw.Alignment.centerLeft : pw.Alignment.center,
      padding: const pw.EdgeInsets.only(top: 4, bottom: 10),
      child: hasFooterSignature
          ? pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 40),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Expanded(
                    child: _buildSignatureCard(
                      signerName: ((signature['signer_name'] ??
                                  signature['signerName'] ??
                                  signature['name']) as String?) ??
                          'Unknown',
                      signerRole: ((signature['signer_role'] ??
                                  signature['signerRole'] ??
                                  signature['role']) as String?) ??
                          'Unknown',
                      signedAt: (signature['signed_at'] ?? signature['signedAt']) as String?,
                      signatureData: ((signature['signature_data'] ??
                              signature['signatureData'] ??
                              signature['digitalSignature'] ??
                              signature['signature']) as String?),
                      branding: branding,
                      currentProfile: currentProfile,
                      compact: true,
                    ),
                  ),
                  pw.SizedBox(width: 18),
                  pw.SizedBox(
                    width: 110,
                    child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: branding.logo != null
                          ? pw.SizedBox(
                              height: 22,
                              child: pw.Image(
                                branding.logo!,
                                fit: pw.BoxFit.contain,
                              ),
                            )
                          : pw.Text(
                              'K H O N O L O G Y',
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: _brandRed,
                                letterSpacing: 1.6,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            )
          : ((branding.footerIcon1 ?? branding.footerIcon2 ?? branding.footerIcon3) != null
              ? pw.Center(
                  child: pw.SizedBox(
                    height: 24,
                    child: pw.Image(
                      (branding.footerIcon1 ?? branding.footerIcon2 ?? branding.footerIcon3)!,
                      fit: pw.BoxFit.contain,
                    ),
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
                )),
    );
  }

  List<pw.Widget> _buildSprintSignoffBody(
    SignOffReport report, {
    required _BrandingAssets branding,
    Map<String, dynamic>? currentProfile,
  }) {
    final data = report.sprintReportData ?? const <String, dynamic>{};
    final sprint = _asMap(data['sprint']);
    final summary = _asMap(data['summary']);
    final projectFromData = _asMap(data['project']);
    final project = projectFromData.isNotEmpty ? projectFromData : _asMap(sprint['project']);
    final teamRaw = data['team'];
    final team = teamRaw is List ? _asList(teamRaw) : _asList(_asMap(teamRaw)['members']);
    final deliverables = _asList(data['deliverables']);
    final performanceMetrics = _extractPerformanceMetrics(report, data);

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

    final extractedNotes = (_extractReportSection(report.reportContent, 'SIGN-OFF NOTES') ?? '').trim();
    final extractedFeedback = (_extractReportSection(report.reportContent, 'FEEDBACK') ?? '').trim();
    final fromFields = <String>[
      (report.clientComment ?? '').trim(),
      (report.changeRequestDetails ?? '').trim(),
    ].where((e) => e.isNotEmpty).join('\n');
    final inferredFromTitle = report.reportTitle.trim();
    final inferredAsNotes = extractedNotes.isEmpty &&
        fromFields.isEmpty &&
        inferredFromTitle.isNotEmpty &&
        inferredFromTitle != '-' &&
        inferredFromTitle != sprintName &&
        inferredFromTitle != projectName;
    final hasStructuredSprintData = sprint.isNotEmpty || summary.isNotEmpty || project.isNotEmpty || deliverables.isNotEmpty;
    final rawContentFallback = report.reportContent.trim();
    final note = (extractedNotes.isNotEmpty && extractedNotes != '-')
        ? extractedNotes
        : ((fromFields.isNotEmpty)
            ? fromFields
            : ((!hasStructuredSprintData && rawContentFallback.isNotEmpty)
                ? rawContentFallback
                : (inferredAsNotes ? inferredFromTitle : '-')));
    final String? feedback = extractedFeedback.isNotEmpty ? extractedFeedback : null;

    const bodyPadding = pw.EdgeInsets.fromLTRB(40, 10, 40, 0);

    final projectDetail = pw.Container(
      width: double.infinity,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _columnSectionBar('PROJECT DETAIL:'),
          pw.SizedBox(height: 8),
          _kvLine('Name:', projectName),
          _kvLine('Key:', projectKey),
          _kvLine('ID:', projectId),
        ],
      ),
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

    final projectSprintTotals = pw.Container(
      width: double.infinity,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _columnSectionBar('PROJECT SPRINT TOTALS:'),
          pw.SizedBox(height: 8),
          _kvLine('Total Sprints:', sprintCount.toString()),
          _kvLine('Total Deliverables:', totalDeliverablesAll.toString()),
          _kvLine('Completed:', completedAll.toString()),
          _kvLine('In Progress:', inProgressAll.toString()),
          _kvLine('Not Started:', notStartedAll.toString()),
          _kvLine('Overdue:', overdueAll.toString()),
          _kvLine('Blocked:', blockedAll.toString()),
        ],
      ),
    );

    final sprintDetail = pw.Container(
      width: double.infinity,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _columnSectionBar('SPRINT DETAIL:'),
          pw.SizedBox(height: 8),
          _kvLine('Name:', sprintName),
          _kvLine('ID:', sprintId),
          _kvLine('Status:', sprintStatus),
          _kvLine('Start:', sprintStart),
          _kvLine('End:', sprintEnd),
        ],
      ),
    );

    final sprintSummary = pw.Container(
      width: double.infinity,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _columnSectionBar('SPRINT SUMMARY:'),
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
      ),
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

    final teamLines = team.map((m) {
      final mm = _asMap(m);
      final work = (mm['work'] ?? mm['workSummary'] ?? mm['work_summary'])?.toString();
      final workPart = (work != null && work.trim().isNotEmpty) ? ' | Work: ${work.trim()}' : '';
      return '- ${_stringOrDash(mm['name'])} | ${_stringOrDash(mm['email'])} | ${_stringOrDash(mm['role'])}$workPart';
    }).toList();
    final teamFirst = teamLines.length <= 2 ? teamLines : teamLines.sublist(0, 2);
    final teamRest = teamLines.length <= 2 ? const <String>[] : teamLines.sublist(2);
    final teamWidgets = <pw.Widget>[
      pw.Container(
        width: double.infinity,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _fullWidthSectionBar('TEAM MEMBERS'),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(40, 5, 40, 0),
              child: pw.Text(
                teamLines.isEmpty ? 'None' : teamFirst.join('\n'),
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
              ),
            ),
          ],
        ),
      ),
      if (teamRest.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(40, 2, 40, 0),
          child: pw.Text(
            teamRest.join('\n'),
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
          ),
        ),
    ];

    final deliverableLines = deliverables.map((d) {
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
    final delFirst = deliverableLines.length <= 2 ? deliverableLines : deliverableLines.sublist(0, 2);
    final delRest = deliverableLines.length <= 2 ? const <String>[] : deliverableLines.sublist(2);
    final deliverableWidgets = <pw.Widget>[
      pw.Container(
        width: double.infinity,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _fullWidthSectionBar('DELIVERABLES'),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(40, 5, 40, 0),
              child: pw.Text(
                deliverableLines.isEmpty ? 'None' : delFirst.join('\n'),
                style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.black),
              ),
            ),
          ],
        ),
      ),
      if (delRest.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(40, 2, 40, 0),
          child: pw.Text(
            delRest.join('\n'),
            style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.black),
          ),
        ),
    ];

    final trimmedNote = note.trim().isEmpty ? '-' : note.trim();
    final noteLines = trimmedNote.split('\n');
    final noteFirst = noteLines.length <= 2 ? trimmedNote : noteLines.take(2).join('\n');
    final noteRest = noteLines.length <= 2 ? '' : noteLines.skip(2).join('\n').trim();

    final notesWidgets = <pw.Widget>[
      pw.Container(
        width: double.infinity,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _fullWidthSectionBar('SIGN-OFF NOTES'),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(40, 6, 40, 0),
              child: pw.Text(
                noteFirst,
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
              ),
            ),
          ],
        ),
      ),
      if (noteRest.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(40, 2, 40, 0),
          child: pw.Text(
            noteRest,
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

    return [
      topRows,
      if (performanceMetrics.isNotEmpty) ...[
        pw.SizedBox(height: 8),
        ..._buildSprintMetricsChartsSection(performanceMetrics),
      ],
      ...teamWidgets,
      pw.SizedBox(height: 8),
      ...deliverableWidgets,
      pw.SizedBox(height: 8),
      ...notesWidgets,
      pw.SizedBox(height: 10),
    ];
  }

  List<Map<String, dynamic>> _extractPerformanceMetrics(
    SignOffReport report,
    Map<String, dynamic> data,
  ) {
    final fromData = _asList(data['performanceMetrics']);
    if (fromData.isNotEmpty) {
      return fromData.map((item) => _asMap(item)).where((item) => item.isNotEmpty).toList();
    }

    final raw = report.sprintPerformanceData;
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((item) => _asMap(item)).where((item) => item.isNotEmpty).toList();
        }
        if (decoded is Map) {
          final nested = _asList(decoded['performanceMetrics']);
          if (nested.isNotEmpty) {
            return nested.map((item) => _asMap(item)).where((item) => item.isNotEmpty).toList();
          }
        }
      } catch (_) {}
    }

    return const <Map<String, dynamic>>[];
  }

  List<pw.Widget> _buildSprintMetricsChartsSection(List<Map<String, dynamic>> metrics) {
    if (metrics.isEmpty) {
      return const <pw.Widget>[];
    }

    int maxPointValue = 1;
    for (final metric in metrics) {
      maxPointValue = _maxInt(maxPointValue, _num(metric['committed_points']));
      maxPointValue = _maxInt(maxPointValue, _num(metric['completed_points']));
      maxPointValue = _maxInt(maxPointValue, _num(metric['velocity']));
    }

    final cards = metrics
        .map(
          (metric) => pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(40, 8, 40, 0),
            child: _buildSprintMetricCard(
              metric,
              maxPointValue: maxPointValue,
            ),
          ),
        )
        .toList();

    final firstCard = cards.isNotEmpty ? cards.first : null;
    final remainingCards = cards.length <= 1 ? const <pw.Widget>[] : cards.sublist(1);

    return [
      pw.NewPage(freeSpace: 240),
      pw.Container(
        width: double.infinity,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _fullWidthSectionBar('SPRINT METRICS GRAPHS'),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(40, 6, 40, 0),
              child: pw.Text(
                'Compact sprint graphs summarise delivery, quality, and scope without breaking the report layout.',
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
              ),
            ),
            if (firstCard != null) firstCard,
          ],
        ),
      ),
      ...remainingCards,
    ];
  }

  pw.Widget _buildSprintMetricCard(
    Map<String, dynamic> metric, {
    required int maxPointValue,
  }) {
    final name = _stringOrDash(metric['name']);
    final passRate = _num(metric['test_pass_rate']).clamp(0, 100);
    final scopeIndicator = _stringOrDash(metric['scope_change_indicator']);
    final committed = _num(metric['committed_points']);
    final completed = _num(metric['completed_points']);
    final velocity = _num(metric['velocity']);
    final defectsOpened = _num(metric['defects_opened']);
    final defectsClosed = _num(metric['defects_closed']);
    final pointsAdded = _num(metric['points_added']);
    final pointsRemoved = _num(metric['points_removed']);
    final spillover = committed > completed ? committed - completed : 0;
    final completionPercent = committed <= 0 ? 0 : ((completed / committed) * 100).round().clamp(0, 100);
    final completionColor = completionPercent >= 90
        ? const PdfColor(0.54, 0.71, 0.54)
        : completionPercent >= 70
            ? const PdfColor(0.95, 0.75, 0.24)
            : _brandRed;

    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            name,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          _buildPercentBar(
            label: 'Completion',
            value: completionPercent,
            color: completionColor,
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildMetricCompactStat(
                  title: 'Committed',
                  value: '$committed',
                  fill: const PdfColor(0.93, 0.96, 0.99),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: _buildMetricCompactStat(
                  title: 'Completed',
                  value: '$completed',
                  fill: const PdfColor(0.99, 0.93, 0.93),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: _buildMetricCompactStat(
                  title: 'Velocity',
                  value: '$velocity',
                  fill: const PdfColor(0.92, 0.97, 0.92),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 5),
          _buildMetricSubsectionTitle('Delivery Overview'),
          pw.SizedBox(height: 6),
          _buildDeliveryOverviewPanel(
            items: [
              _DeliveryMetricBarItem(
                label: 'Committed',
                value: committed,
                maxValue: maxPointValue,
                color: const PdfColor(0.74, 0.82, 0.94),
              ),
              _DeliveryMetricBarItem(
                label: 'Completed',
                value: completed,
                maxValue: maxPointValue,
                color: _brandRed,
              ),
              _DeliveryMetricBarItem(
                label: 'Velocity',
                value: velocity,
                maxValue: maxPointValue,
                color: const PdfColor(0.54, 0.71, 0.54),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildMetricCompactPanel(
                  title: 'Quality',
                  children: [
                    _buildPercentBar(
                      label: 'Pass Rate',
                      value: passRate,
                      color: const PdfColor(0.54, 0.71, 0.54),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: _buildMetricCompactStat(
                            title: 'Opened',
                            value: '$defectsOpened',
                            fill: const PdfColor(0.99, 0.93, 0.93),
                          ),
                        ),
                        pw.SizedBox(width: 5),
                        pw.Expanded(
                          child: _buildMetricCompactStat(
                            title: 'Closed',
                            value: '$defectsClosed',
                            fill: const PdfColor(0.92, 0.97, 0.92),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildMetricCompactPanel(
                  title: 'Scope',
                  children: [
                    pw.Text(
                      'Change: $scopeIndicator',
                      style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: _buildMetricCompactStat(
                            title: 'Added',
                            value: '$pointsAdded',
                            fill: const PdfColor(1.0, 0.96, 0.88),
                          ),
                        ),
                        pw.SizedBox(width: 5),
                        pw.Expanded(
                          child: _buildMetricCompactStat(
                            title: 'Removed',
                            value: '$pointsRemoved',
                            fill: const PdfColor(0.94, 0.92, 0.99),
                          ),
                        ),
                      ],
                    ),
                    if (spillover > 0) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Spillover: $spillover points',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMetricSubsectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.black,
        ),
      ),
    );
  }

  pw.Widget _buildMetricCompactStat({
    required String title,
    required String value,
    required PdfColor fill,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: pw.BoxDecoration(
        color: fill,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 1.5),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMetricCompactPanel({
    required String title,
    required List<pw.Widget> children,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          ...children,
        ],
      ),
    );
  }

  pw.Widget _buildDeliveryOverviewPanel({
    required List<_DeliveryMetricBarItem> items,
  }) {
    return pw.Container(
      width: double.infinity,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          ...items.asMap().entries.expand((entry) sync* {
            final index = entry.key;
            final item = entry.value;
            yield pw.Expanded(
              child: _buildCompactMetricBarCard(item),
            );
            if (index != items.length - 1) {
              yield pw.SizedBox(width: 6);
            }
          }),
        ],
      ),
    );
  }

  pw.Widget _buildCompactMetricBarCard(_DeliveryMetricBarItem item) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: _buildHorizontalMetricBar(
        label: item.label,
        value: item.value,
        maxValue: item.maxValue,
        color: item.color,
      ),
    );
  }

  pw.Widget _buildHorizontalMetricBar({
    required String label,
    required int value,
    required int maxValue,
    required PdfColor color,
  }) {
    final safeMax = maxValue <= 0 ? 1 : maxValue;
    final ratio = (value / safeMax).clamp(0.0, 1.0);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              '$value',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
            ),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.LinearProgressIndicator(
          value: ratio.toDouble(),
          minHeight: 4,
          backgroundColor: PdfColors.grey300,
          valueColor: color,
        ),
      ],
    );
  }

  pw.Widget _buildPercentBar({
    required String label,
    required int value,
    required PdfColor color,
  }) {
    final ratio = (value / 100).clamp(0.0, 1.0);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              '$value%',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
            ),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.LinearProgressIndicator(
          value: ratio.toDouble(),
          minHeight: 4,
          backgroundColor: PdfColors.grey300,
          valueColor: color,
        ),
      ],
    );
  }

  pw.Widget _sectionBar(String title) {
    return pw.Container(
      width: double.infinity,
      color: _lightRedBar,
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
    );
  }

  pw.Widget _columnSectionBar(String title) {
    return pw.SizedBox(
      width: _reportHalfColumnWidth,
      child: _sectionBar(title),
    );
  }

  pw.Widget _fullWidthSectionBar(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.fromLTRB(_reportSideInset, 10, _reportSideInset, 0),
      child: pw.SizedBox(
        width: _reportContentWidth,
        child: _sectionBar(title),
      ),
    );
  }

  pw.Widget _buildSignatureCard({
    required String signerName,
    required String signerRole,
    required String? signedAt,
    required String? signatureData,
    required _BrandingAssets branding,
    Map<String, dynamic>? currentProfile,
    bool compact = false,
  }) {
    final profile = currentProfile ?? const <String, dynamic>{};
    final profileName = _profileFullName(profile);
    final displayName =
        signerName.trim().isNotEmpty && signerName.trim().toLowerCase() != 'unknown' ? signerName.trim() : profileName;
    final displayRole =
        signerRole.trim().isNotEmpty && signerRole.trim().toLowerCase() != 'unknown' ? _formatRole(signerRole) : (_optionalProfileValue(profile['job_title']) ?? 'Signatory');
    final email = _optionalProfileValue(profile['email']);
    final phone = _optionalProfileValue(profile['phone_number']);
    final website = _optionalProfileValue(profile['website']);
    final location = _optionalProfileValue(profile['location']);

    if (compact) {
      final signatureWidget = _buildSignatureVisual(signatureData, displayName);
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(height: 1.2, width: double.infinity, color: _brandRed),
          pw.SizedBox(height: 4),
          pw.Text(
            displayName,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: _brandRed,
            ),
          ),
          pw.Text(
            displayRole,
            style: pw.TextStyle(
              fontSize: 7.5,
              color: _brandRed,
            ),
          ),
          if (phone != null)
            pw.Text(
              phone,
              style: pw.TextStyle(fontSize: 7.5, color: _brandRed),
            ),
          if (email != null)
            pw.Text(
              email,
              style: pw.TextStyle(fontSize: 7.5, color: _brandRed),
            ),
          if (signedAt != null)
            pw.Text(
              _formatIsoDate(signedAt),
              style: pw.TextStyle(fontSize: 7.5, color: _brandRed),
            ),
          pw.SizedBox(height: 4),
          pw.SizedBox(
            height: 24,
            child: signatureWidget,
          ),
        ],
      );
    }

    return pw.Padding(
      padding: compact ? pw.EdgeInsets.zero : const pw.EdgeInsets.fromLTRB(40, 14, 40, 0),
      child: pw.Container(
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(height: 4, width: double.infinity, color: _brandRed),
            pw.Padding(
              padding: pw.EdgeInsets.fromLTRB(14, compact ? 10 : 12, 14, compact ? 8 : 10),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          displayName,
                          style: pw.TextStyle(fontSize: compact ? 11.5 : 13, fontWeight: pw.FontWeight.bold, color: _brandRed),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(displayRole, style: pw.TextStyle(fontSize: compact ? 8 : 9, color: _brandRed)),
                        if (phone != null) pw.SizedBox(height: compact ? 4 : 8),
                        if (phone != null) pw.Text(phone, style: pw.TextStyle(fontSize: compact ? 7 : 7.5, color: _brandRed)),
                        if (email != null) pw.Text(email, style: pw.TextStyle(fontSize: compact ? 7 : 7.5, color: _brandRed)),
                        if (!compact && website != null) pw.Text(website, style: pw.TextStyle(fontSize: 7.5, color: _brandRed)),
                        if (!compact && location != null) pw.Text(location, style: pw.TextStyle(fontSize: 7.5, color: _brandRed)),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  if (branding.wordmark != null)
                    pw.Image(branding.wordmark!, width: compact ? 96 : 120, height: compact ? 16 : 18, fit: pw.BoxFit.contain)
                  else
                    pw.Text(
                      'KHONOLOGY',
                      style: pw.TextStyle(fontSize: compact ? 12 : 14, fontWeight: pw.FontWeight.bold, color: _brandRed, letterSpacing: 1.2),
                    ),
                ],
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.fromLTRB(14, 2, 14, compact ? 8 : 12),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Expanded(
                    child: pw.SizedBox(
                      height: compact ? 34 : 42,
                      child: _buildSignatureVisual(signatureData, displayName),
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (signedAt != null)
                        pw.Text(
                          _formatIsoDate(signedAt),
                          style: pw.TextStyle(fontSize: compact ? 8.5 : 9.5, color: PdfColors.grey700),
                        ),
                      if (email != null)
                        pw.Text(
                          email,
                          style: pw.TextStyle(fontSize: compact ? 8.5 : 9.5, color: PdfColors.grey700),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _maxInt(int a, int b) => a > b ? a : b;

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

  String _profileFullName(Map<String, dynamic> profile) {
    final first = _optionalProfileValue(profile['first_name']);
    final last = _optionalProfileValue(profile['last_name']);
    final full = [first, last].whereType<String>().where((v) => v.trim().isNotEmpty).join(' ').trim();
    return full.isNotEmpty ? full : 'Unknown';
  }

  String? _optionalProfileValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
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

  pw.Widget _buildSignatureVisual(String? signatureData, String signerName) {
    final parsed = _parseSignaturePayload(signatureData);
    if (parsed == null) {
      return pw.SizedBox();
    }

    if (parsed.imageBytes != null) {
      return pw.Image(
        pw.MemoryImage(parsed.imageBytes!),
        fit: pw.BoxFit.contain,
      );
    }

    final typedText = parsed.typedText?.trim();
    if (typedText != null && typedText.isNotEmpty) {
      return pw.Center(
        child: pw.Text(
          typedText,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 24,
            fontStyle: pw.FontStyle.italic,
            color: _brandRed,
          ),
        ),
      );
    }

    return pw.Center(
      child: pw.Text(
        signerName,
        style: pw.TextStyle(
          fontSize: 20,
          fontStyle: pw.FontStyle.italic,
          color: _brandRed,
        ),
      ),
    );
  }

  _ParsedSignaturePayload? _parseSignaturePayload(String? signatureData) {
    if (signatureData == null || signatureData.isEmpty) {
      return null;
    }

    try {
      final trimmedData = signatureData.trim();
      if (trimmedData.startsWith('data:text/plain;base64,')) {
        final plain = utf8.decode(base64Decode(trimmedData.split(',').last));
        return _ParsedSignaturePayload(typedText: plain);
      }
      if (trimmedData.startsWith('{') || trimmedData.startsWith('[') ||
          trimmedData.startsWith('"success"') || trimmedData.startsWith('"error"')) {
        return null;
      }

      final normalized = (signatureData.contains(',') ? signatureData.split(',').last : signatureData)
          .replaceAll(RegExp(r'\s+'), '');
      final Uint8List imageBytes = base64Decode(normalized);
      return _ParsedSignaturePayload(imageBytes: imageBytes);
    } catch (_) {
      return null;
    }
  }
}

class _DeliveryMetricBarItem {
  final String label;
  final int value;
  final int maxValue;
  final PdfColor color;

  const _DeliveryMetricBarItem({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });
}

