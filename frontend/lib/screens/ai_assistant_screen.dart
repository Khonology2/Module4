import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:universal_html/html.dart' as html;
import '../services/backend_api_service.dart';
import '../services/report_export_service.dart';
import '../services/api_client.dart';
import '../models/sign_off_report.dart';
import '../utils/export_feedback.dart';
import '../widgets/signature_capture_widget.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  static const List<String> _seedSuggestions = <String>[
    'Help me find active sprints',
    'Show my projects',
    'Create a sprint sign-off report',
    'Check for overdue deliverables',
  ];

  static const String _systemPrompt =
      'You are FlowPilot, a friendly assistant for a project delivery and sign-off tool. '
      'Collaborate with the user: ask clarifying questions, offer 2–4 helpful options, and guide them step-by-step. '
      'Keep responses concise, practical, and respectful. '
      'Never invent data; if something is missing, say what you need to proceed.';

  static const String _welcomeMessage =
      "Hi! I’m FlowPilot.\n\nTell me what you’re trying to do and I’ll guide you through it. "
      "If you want to start quickly, pick one of the options below.";

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <Map<String, dynamic>>[
    {
      'role': 'system',
      'content': _systemPrompt,
    },
    {
      'role': 'assistant',
      'content': _welcomeMessage,
    },
  ];

  bool _isSending = false;
  bool _hasUserStartedConversation = false;
  List<String> _quickSuggestions = const <String>[];
  List<String> _serverSuggestions = const <String>[];
  final Set<String> _downloadsInProgress = <String>{};
  final Map<String, SignOffReport> _reportCache = <String, SignOffReport>{};
  final Map<String, Future<PdfBytesResult>> _pdfBuildCache = <String, Future<PdfBytesResult>>{};

  @override
  void initState() {
    super.initState();
    ReportExportService().warmup();
    _controller.addListener(_recomputeQuickSuggestions);
    _recomputeQuickSuggestions();
  }

  @override
  void dispose() {
    _controller.removeListener(_recomputeQuickSuggestions);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      if (!_hasUserStartedConversation) {
        _hasUserStartedConversation = true;
        for (final m in _messages) {
          m.remove('suggestions');
        }
        _quickSuggestions = const <String>[];
      }
      _isSending = true;
      _messages.add({'role': 'user', 'content': text});
      _controller.clear();
    });

    try {
      final system = _messages.firstWhere(
        (m) => (m['role'] ?? '').toString() == 'system',
        orElse: () => <String, dynamic>{'role': 'system', 'content': _systemPrompt},
      );
      final recent = _messages.where((m) => (m['role'] ?? '').toString() != 'system').toList();
      final start = recent.length > 12 ? recent.length - 12 : 0;
      final outbound = <Map<String, dynamic>>[
        <String, dynamic>{
          'role': (system['role'] ?? 'system').toString(),
          'content': (system['content'] ?? _systemPrompt).toString(),
        },
        ...recent.sublist(start).map((m) => <String, dynamic>{
              'role': (m['role'] ?? '').toString(),
              'content': (m['content'] ?? '').toString(),
            }),
      ];
      final resp = await BackendApiService().aiChat(outbound, temperature: 0.4, maxTokens: 350);
      final root = resp.data is Map ? Map<String, dynamic>.from(resp.data as Map) : <String, dynamic>{};
      final data = root['data'] is Map ? Map<String, dynamic>.from(root['data'] as Map) : root;
      final content = (data['content'] ?? data['message'])
          ?.toString()
          .trim();
      final actions = data['actions'] is List ? List<dynamic>.from(data['actions'] as List) : const <dynamic>[];
      final suggestions = data['suggestions'] is List
          ? (data['suggestions'] as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
          : const <String>[];

      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': resp.isSuccess ? (content?.isNotEmpty == true ? content! : 'No response received.') : (resp.error ?? 'Request failed.'),
          if (actions.isNotEmpty) 'actions': actions,
        });
        if (!_hasUserStartedConversation && suggestions.isNotEmpty) _serverSuggestions = suggestions;
      });
      if (actions.isNotEmpty) {
        _prefetchReportsForActions(actions);
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': 'Error: $e'});
      });
    } finally {
      setState(() => _isSending = false);
      if (mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      }
    }
  }

  void _recomputeQuickSuggestions() {
    if (_hasUserStartedConversation) {
      if (_quickSuggestions.isNotEmpty && mounted) {
        setState(() => _quickSuggestions = const <String>[]);
      }
      return;
    }
    final t = _controller.text.trim().toLowerCase();
    final base = <String>[..._seedSuggestions, ..._serverSuggestions];

    final out = <String>[];
    final seen = <String>{};
    for (final s in base) {
      final v = s.trim();
      if (v.isEmpty) continue;
      final k = _normalizeSuggestion(v);
      if (seen.contains(k)) continue;
      if (t.isEmpty || v.toLowerCase().contains(t) || t.contains(v.toLowerCase().split(' ').first)) {
        out.add(v);
        seen.add(k);
      }
      if (out.length >= 4) break;
    }

    if (mounted) {
      setState(() => _quickSuggestions = out);
    }
  }

  String _normalizeSuggestion(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  Future<void> _runSuggestion(String text) async {
    _controller.text = text;
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    await _send();
  }

  Future<void> _downloadAssistantPdfFromAction(Map<String, dynamic> action) async {
    final reportId = (action['reportId'] ?? action['report_id'] ?? action['id'])?.toString().trim();
    if (reportId != null && reportId.isNotEmpty) {
      final meta = action['metadata'];
      final metaMap = meta is Map ? Map<String, dynamic>.from(meta) : const <String, dynamic>{};
      final suggestedTitle = _pickSuggestedTitle(action: action, meta: metaMap);

      if (!kIsWeb) {
        final cachedPdfFuture = _pdfBuildCache[reportId];
        if (cachedPdfFuture != null) {
          try {
            final cached = await cachedPdfFuture;
            if (suggestedTitle.isEmpty || cached.exportTitle == suggestedTitle) {
              await ReportExportService().exportPdfBytes(cached);
              return;
            }
            _pdfBuildCache.remove(reportId);
          } catch (_) {
            _pdfBuildCache.remove(reportId);
          }
        }
      }
      final cached = _reportCache[reportId];
      SignOffReport report;
      if (cached != null) {
        report = cached;
      } else {
        report = _buildReportFromAction(reportId: reportId, action: action);
        if (report.sprintReportData == null && (report.sprintPerformanceData?.trim().isNotEmpty ?? false)) {
          try {
            final decoded = jsonDecode(report.sprintPerformanceData!);
            if (decoded is Map) {
              report = report.copyWith(sprintReportData: Map<String, dynamic>.from(decoded));
            }
          } catch (_) {}
        }
        try {
          final resp = await BackendApiService().getSignOffReport(reportId, timeout: const Duration(milliseconds: 800));
          if (resp.isSuccess && resp.data != null) {
            final data = resp.data is Map ? Map<String, dynamic>.from(resp.data) : <String, dynamic>{};
            final parsed = SignOffReport.fromJson(data);
            report = parsed.copyWith(
              reportTitle: report.reportTitle.trim().isNotEmpty ? report.reportTitle : parsed.reportTitle,
              reportContent: report.reportContent.trim().isNotEmpty ? report.reportContent : parsed.reportContent,
              sprintPerformanceData: report.sprintPerformanceData?.trim().isNotEmpty == true
                  ? report.sprintPerformanceData
                  : parsed.sprintPerformanceData,
              sprintReportData: report.sprintReportData ?? parsed.sprintReportData,
              digitalSignature: report.digitalSignature?.trim().isNotEmpty == true ? report.digitalSignature : parsed.digitalSignature,
            );
          }
        } catch (_) {}
        _reportCache[reportId] = report;
      }

      if (suggestedTitle.isNotEmpty && suggestedTitle != report.reportTitle) {
        try {
          final updates = <String, dynamic>{'reportTitle': suggestedTitle};
          updates['content'] = <String, dynamic>{
            'reportTitle': suggestedTitle,
            'title': suggestedTitle,
          };
          updates['report_title'] = suggestedTitle;

          Map<String, dynamic>? perfMap;
          final perf = report.sprintPerformanceData;
          if (perf != null && perf.trim().isNotEmpty) {
            try {
              final decoded = jsonDecode(perf);
              if (decoded is Map) perfMap = Map<String, dynamic>.from(decoded);
            } catch (_) {}
          }
          final sprintData = (report.sprintReportData != null && report.sprintReportData!.isNotEmpty)
              ? Map<String, dynamic>.from(report.sprintReportData!)
              : <String, dynamic>{};
          sprintData['title'] = suggestedTitle;
          sprintData['reportTitle'] = suggestedTitle;
          sprintData['aiTitle'] = suggestedTitle;
          updates['sprintReportData'] = sprintData;
          updates['sprint_report_data'] = sprintData;

          if (perfMap != null) {
            perfMap['title'] = suggestedTitle;
            perfMap['reportTitle'] = suggestedTitle;
            perfMap['aiTitle'] = suggestedTitle;
            updates['sprintPerformanceData'] = jsonEncode(perfMap);
            updates['sprint_performance_data'] = updates['sprintPerformanceData'];
          }

          BackendApiService().updateSignOffReport(reportId, updates);
          report = report.copyWith(
            reportTitle: suggestedTitle,
            sprintPerformanceData: updates['sprintPerformanceData']?.toString() ?? report.sprintPerformanceData,
            sprintReportData: sprintData,
          );
          _reportCache[reportId] = report;
        } catch (_) {}
      }

      final perf = report.sprintPerformanceData;
      if ((report.sprintReportData == null || report.sprintReportData!.isEmpty) &&
          perf != null &&
          perf.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(perf);
          if (decoded is Map) {
            report = report.copyWith(sprintReportData: Map<String, dynamic>.from(decoded));
          }
        } catch (_) {}
      }

      final existingSig = report.digitalSignature?.trim() ?? '';
      if (existingSig.isEmpty) {
        final signature = await _promptForSignature(reportId: reportId);
        if (signature != null && signature.trim().isNotEmpty) {
          report = report.copyWith(digitalSignature: signature);
          _reportCache[reportId] = report;
          try {
            unawaited(
              ApiClient().post(
                '/sign-off-reports/$reportId/signature',
                body: {
                  'signatureData': signature,
                  'signatureType': 'manual',
                },
                timeout: const Duration(seconds: 2),
              ),
            );
          } catch (_) {}
          try {
            BackendApiService().updateSignOffReport(reportId, {'digitalSignature': signature}, timeout: const Duration(seconds: 2));
          } catch (_) {}
        }
      }

      final exporter = ReportExportService();
      await exporter.exportReportAsPDFFromServer(report);
      return;
    }

    final title = (action['title'] ?? 'Report').toString();
    final content = (action['content'] ?? '').toString();
    await _downloadTextPdf(title: title, content: content);
  }

  void _prefetchReportsForActions(List<dynamic> actions) {
    for (final a in actions) {
      if (a is! Map) continue;
      final m = Map<String, dynamic>.from(a);
      final type = (m['type'] ?? m['action'] ?? '').toString();
      if (type != 'export_pdf') continue;
      final reportId = (m['reportId'] ?? m['report_id'] ?? m['id'])?.toString().trim();
      if (reportId == null || reportId.isEmpty) continue;
      if (_reportCache.containsKey(reportId)) continue;

      unawaited(Future(() async {
        final meta = m['metadata'];
        final metaMap = meta is Map ? Map<String, dynamic>.from(meta) : const <String, dynamic>{};
        final suggestedTitle = _pickSuggestedTitle(action: m, meta: metaMap);
        SignOffReport report = _buildReportFromAction(reportId: reportId, action: m);
        try {
          final resp = await BackendApiService().getSignOffReport(reportId, timeout: const Duration(milliseconds: 800));
          if (resp.isSuccess && resp.data != null) {
            final data = resp.data is Map ? Map<String, dynamic>.from(resp.data) : <String, dynamic>{};
            final parsed = SignOffReport.fromJson(data);
            report = parsed.copyWith(
              reportTitle: report.reportTitle.trim().isNotEmpty ? report.reportTitle : parsed.reportTitle,
              reportContent: report.reportContent.trim().isNotEmpty ? report.reportContent : parsed.reportContent,
              sprintPerformanceData: report.sprintPerformanceData?.trim().isNotEmpty == true
                  ? report.sprintPerformanceData
                  : parsed.sprintPerformanceData,
              sprintReportData: report.sprintReportData ?? parsed.sprintReportData,
            );
          }
        } catch (_) {}
        if (mounted) {
          _reportCache[reportId] = report;
        }
        if (suggestedTitle.isNotEmpty) {
          try {
            final updates = <String, dynamic>{
              'reportTitle': suggestedTitle,
              'report_title': suggestedTitle,
              'content': <String, dynamic>{
                'reportTitle': suggestedTitle,
                'title': suggestedTitle,
              },
            };
            final sprintData = (report.sprintReportData != null && report.sprintReportData!.isNotEmpty)
                ? Map<String, dynamic>.from(report.sprintReportData!)
                : <String, dynamic>{};
            sprintData['title'] = suggestedTitle;
            sprintData['reportTitle'] = suggestedTitle;
            sprintData['aiTitle'] = suggestedTitle;
            updates['sprintReportData'] = sprintData;
            updates['sprint_report_data'] = sprintData;
            BackendApiService().updateSignOffReport(reportId, updates);
          } catch (_) {}
        }
      }));
    }
  }

  String _pickSuggestedTitle({required Map<String, dynamic> action, required Map<String, dynamic> meta}) {
    final titleFallback = (action['title'] ?? meta['title'] ?? '').toString().trim();

    final candidates = <String>[
      (action['suggestedTitle'] ?? '').toString(),
      (action['aiTitle'] ?? '').toString(),
      (meta['suggestedTitle'] ?? '').toString(),
      (meta['aiTitle'] ?? '').toString(),
      (action['reportTitle'] ?? '').toString(),
      (action['report_title'] ?? '').toString(),
      (meta['reportTitle'] ?? '').toString(),
      (meta['report_title'] ?? '').toString(),
      if (_looksLikeReportTitle(titleFallback) && _looksLikeLikelyTitleLabel(titleFallback)) titleFallback,
    ].map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    int score(String s) {
      final v = s.trim();
      if (v.isEmpty) return -999;
      if (!_looksLikeReportTitle(v)) return -50;
      int sc = 100;
      if (_looksLikeFeedbackText(v)) sc -= 120;
      if (v.length < 6) sc -= 10;
      sc -= (v.length ~/ 12);
      return sc;
    }

    candidates.sort((a, b) => score(b).compareTo(score(a)));
    final best = candidates.isNotEmpty ? candidates.first : '';
    if (_looksLikeReportTitle(best) && !_looksLikeFeedbackText(best)) return best;
    final fallback = _deriveTitleFromSprintData(action: action, meta: meta);
    if (fallback.isNotEmpty) return fallback;
    return '';
  }

  bool _looksLikeLikelyTitleLabel(String s) {
    final v = s.trim().toLowerCase();
    if (v.isEmpty) return false;
    if (v.contains('sign-off')) return true;
    if (v.contains('sign off')) return true;
    if (v.contains('sprint')) return true;
    if (v.contains('report')) return true;
    return false;
  }

  String _deriveTitleFromSprintData({required Map<String, dynamic> action, required Map<String, dynamic> meta}) {
    Map<String, dynamic>? data;
    final raw = (action['sprintPerformanceData'] ??
            action['sprint_performance_data'] ??
            meta['sprintPerformanceData'] ??
            meta['sprint_performance_data'])
        ?.toString();
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    if (data == null) {
      final d = action['sprintReportData'] is Map
          ? Map<String, dynamic>.from(action['sprintReportData'] as Map)
          : (meta['sprintReportData'] is Map ? Map<String, dynamic>.from(meta['sprintReportData'] as Map) : null);
      if (d != null && d.isNotEmpty) data = d;
    }
    if (data == null || data.isEmpty) return '';
    final sprint = (data['sprint'] is Map) ? Map<String, dynamic>.from(data['sprint'] as Map) : const <String, dynamic>{};
    final project = (data['project'] is Map)
        ? Map<String, dynamic>.from(data['project'] as Map)
        : (sprint['project'] is Map ? Map<String, dynamic>.from(sprint['project'] as Map) : const <String, dynamic>{});
    final sprintName = (sprint['name'] ?? '').toString().trim();
    final projectName = (project['name'] ?? '').toString().trim();
    if (projectName.isNotEmpty && sprintName.isNotEmpty) return 'Sprint Sign-Off: $projectName — $sprintName';
    if (sprintName.isNotEmpty) return 'Sprint Sign-Off: $sprintName';
    return '';
  }

  bool _looksLikeFeedbackText(String s) {
    final v = s.trim();
    if (v.isEmpty) return false;
    final lower = v.toLowerCase();
    if (lower.contains('feedback')) return true;
    if (lower.contains('comment')) return true;
    if (lower.contains('change request')) return true;
    if (lower.contains('requested change')) return true;
    if (lower.contains('issue')) return true;
    if (lower.startsWith('i ')) return true;
    if (lower.contains('please')) return true;
    return false;
  }

  SignOffReport _buildReportFromAction({required String reportId, required Map<String, dynamic> action}) {
    final meta = action['metadata'];
    final metaMap = meta is Map ? Map<String, dynamic>.from(meta) : const <String, dynamic>{};
    final suggestedTitle = _pickSuggestedTitle(action: action, meta: metaMap);

    final raw = (action['sprintPerformanceData'] ??
            action['sprint_performance_data'] ??
            metaMap['sprintPerformanceData'] ??
            metaMap['sprint_performance_data'])
        ?.toString();
    Map<String, dynamic>? sprintData;
    if (action['sprintReportData'] is Map) {
      sprintData = Map<String, dynamic>.from(action['sprintReportData'] as Map);
    } else if (metaMap['sprintReportData'] is Map) {
      sprintData = Map<String, dynamic>.from(metaMap['sprintReportData'] as Map);
    } else if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) sprintData = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    if (suggestedTitle.isNotEmpty) {
      sprintData ??= <String, dynamic>{};
      sprintData['title'] = suggestedTitle;
      sprintData['reportTitle'] = suggestedTitle;
      sprintData['aiTitle'] = suggestedTitle;
    }

    final content = (action['reportContent'] ??
            action['report_content'] ??
            action['content'] ??
            metaMap['reportContent'] ??
            metaMap['report_content'] ??
            metaMap['content'])
        ?.toString();

    return SignOffReport(
      id: reportId,
      deliverableId: (action['deliverableId'] ?? action['deliverable_id'] ?? metaMap['deliverableId'] ?? metaMap['deliverable_id'] ?? '').toString(),
      reportTitle: suggestedTitle,
      reportContent: content?.toString() ?? '',
      sprintIds: const <String>[],
      sprintPerformanceData: raw,
      sprintReportData: sprintData,
      knownLimitations: null,
      nextSteps: null,
      preparedBy: null,
      preparedByName: null,
      preparedByRole: null,
      status: ReportStatus.draft,
      createdAt: DateTime.now(),
      createdBy: '',
      submittedAt: null,
      submittedBy: null,
      submittedByName: null,
      submittedByRole: null,
      reviewedAt: null,
      reviewedBy: null,
      reviewedByName: null,
      reviewedByRole: null,
      clientComment: null,
      changeRequestDetails: null,
      changeRequestHistory: null,
      approvedAt: null,
      approvedBy: null,
      approvedByName: null,
      approvedByRole: null,
      digitalSignature: null,
    );
  }

  bool _looksLikeReportTitle(String s) {
    final v = s.trim();
    if (v.isEmpty) return false;
    if (v.length > 120) return false;
    if (v.contains('\n')) return false;
    final lower = v.toLowerCase();
    if (lower.startsWith('download')) return false;
    if (lower.contains('pdf')) return false;
    if (lower.contains('click')) return false;
    return true;
  }

  Future<String?> _promptForSignature({required String reportId}) async {
    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final signatureKey = GlobalKey<SignatureCaptureWidgetState>();
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 520),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Digital Signature',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Please sign to include your signature on the report.'),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      color: Colors.black87,
                      padding: const EdgeInsets.all(12),
                      child: SignatureCaptureWidget(
                        key: signatureKey,
                        showAuditInfo: false,
                        reportId: reportId,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(''),
                        child: const Text('Skip'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () async {
                          final sig = await signatureKey.currentState?.getSignature();
                          if (!context.mounted) return;
                          Navigator.of(context).pop(sig);
                        },
                        child: const Text('Continue'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    return result;
  }

  Future<bool> _promptForReportAuthorization({required String reportId}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Authorize Report Download'),
          content: const Text(
            'You are about to generate and download the final report PDF. This runs in the background, and you can keep using the app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Authorize'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _downloadTextPdf({required String title, required String content}) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) => [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Text(content, style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
    final bytes = await pdf.save();

    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final fileName = '${title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_')}.pdf';
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click()
        ..remove();
      html.Url.revokeObjectUrl(url);
    } else {
      final fileName = '${title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_')}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    }
  }

  Widget _buildMessageCard(Map<String, dynamic> m) {
    final role = (m['role'] ?? '').toString().toLowerCase();
    final isUser = role == 'user';
    final content = (m['content'] ?? '').toString();
    final actionsRaw = m['actions'];
    final actions = actionsRaw is List ? actionsRaw.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList() : const <Map<String, dynamic>>[];

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Card(
          color: isUser ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(content),
                if (!isUser && actions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: actions.map((a) {
                      final type = (a['type'] ?? '').toString();
                      if (type != 'export_pdf') return const SizedBox.shrink();
                      final rid = (a['reportId'] ?? a['report_id'] ?? a['id'])?.toString().trim() ?? '';
                      final isDownloadingThis = rid.isNotEmpty && _downloadsInProgress.contains(rid);
                      return FilledButton.icon(
                        onPressed: isDownloadingThis
                            ? null
                            : () async {
                                final reportId = rid;
                                if (reportId.isNotEmpty) {
                                  setState(() => _downloadsInProgress.add(reportId));
                                }
                                try {
                                  var report = _reportCache[reportId] ?? _buildReportFromAction(reportId: reportId, action: a);
                                  final existingSig = report.digitalSignature?.trim() ?? '';
                                  if (existingSig.isEmpty) {
                                    final signature = await _promptForSignature(reportId: reportId);
                                    if (signature != null && signature.trim().isNotEmpty) {
                                      report = report.copyWith(digitalSignature: signature);
                                      _reportCache[reportId] = report;
                                      try {
                                        unawaited(
                                          ApiClient().post(
                                            '/sign-off-reports/$reportId/signature',
                                            body: {
                                              'signatureData': signature,
                                              'signatureType': 'manual',
                                            },
                                            timeout: const Duration(seconds: 2),
                                          ),
                                        );
                                      } catch (_) {}
                                      try {
                                        BackendApiService().updateSignOffReport(
                                          reportId,
                                          {'digitalSignature': signature},
                                          timeout: const Duration(seconds: 2),
                                        );
                                      } catch (_) {}
                                    }
                                  }

                                  if (!mounted) return;
                                  final authorized = await _promptForReportAuthorization(reportId: reportId);
                                  if (!authorized) {
                                    if (!mounted) return;
                                    if (reportId.isNotEmpty) {
                                      setState(() => _downloadsInProgress.remove(reportId));
                                    }
                                    return;
                                  }

                                  if (!mounted) return;
                                  final messenger = ScaffoldMessenger.of(context);
                                  showDismissibleExportSnackBar(
                                    messenger,
                                    'Preparing your PDF in the background. You can use other screens while it completes.',
                                    backgroundColor: Colors.blue,
                                    duration: const Duration(seconds: 12),
                                  );

                                  unawaited(Future(() async {
                                    try {
                                      await WidgetsBinding.instance.endOfFrame;
                                      await _downloadAssistantPdfFromAction(a);
                                      if (!mounted) return;
                                      showDismissibleExportSnackBar(
                                        messenger,
                                        'PDF download started. Check your downloads folder.',
                                        backgroundColor: Colors.green,
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      showDismissibleExportSnackBar(
                                        messenger,
                                        e.toString(),
                                        backgroundColor: Colors.red,
                                      );
                                    } finally {
                                      if (mounted && reportId.isNotEmpty) {
                                        setState(() => _downloadsInProgress.remove(reportId));
                                      }
                                    }
                                  }));
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                  if (reportId.isNotEmpty) {
                                    setState(() => _downloadsInProgress.remove(reportId));
                                  }
                                }
                              },
                        icon: const Icon(Icons.picture_as_pdf),
                        label: Text(isDownloadingThis ? 'Preparing…' : 'Download PDF'),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _messages.where((m) => m['role'] != 'system').toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: _isSending
                ? null
                : () {
                    setState(() {
                      _hasUserStartedConversation = false;
                      _quickSuggestions = const <String>[];
                      _serverSuggestions = const <String>[];
                      _messages
                        ..clear()
                        ..add({
                          'role': 'system',
                          'content':
                              _systemPrompt,
                        })
                        ..add({
                          'role': 'assistant',
                          'content':
                              _welcomeMessage,
                        });
                    });
                    _recomputeQuickSuggestions();
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final m = visible[index];
                return _buildMessageCard(m);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_hasUserStartedConversation && _quickSuggestions.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _quickSuggestions.map((s) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                label: Text(s),
                                onPressed: _isSending ? null : () => _runSuggestion(s),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  if (!_hasUserStartedConversation && _quickSuggestions.isNotEmpty) const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'Ask a question, or describe what you need help with…',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _isSending ? null : _send,
                        child: Text(_isSending ? 'Sending…' : 'Send'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
