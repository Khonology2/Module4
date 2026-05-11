import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:math';
import '../services/backend_api_service.dart';
import '../services/report_export_service.dart';
import '../services/api_client.dart';
import '../services/signature_service.dart';
import '../services/auth_service.dart';
import '../models/user_signature.dart';
import '../widgets/signature_capture_widget.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  String _lastConfirmedReportTitle = '';
  final _messages = <Map<String, String>>[
    {
      'role': 'system',
      'content':
          'You are FlowPilot, a proactive assistant inside a sprint and deliverables sign-off app. Write in a natural, confident, AI tone (not robotic). Keep responses concise but complete, and ask focused follow-up questions only when needed. Do not fabricate data.\n\nWhen generating a Sprint Sign-Off Report:\n- Use the sprint name as the report title.\n- Present the report in clean sections (Project, Sprint, Sprint Summary, Team Members, Deliverables, Sign-Off Notes).\n- Before exporting a PDF, prompt the user to add a digital signature for the “Prepared By” section (so the final PDF includes their signature).',
    },
  ];

  bool _isSending = false;
  List<String> _suggestions = [];

  List<String> _buildLocalSuggestions() {
    final pool = <String>[
      'Show me all projects.',
      'What sprints are currently active?',
      'Help me create a deliverable.',
      'Help me set up a new sprint.',
      'Show me what is overdue.',
      'What should I focus on next?',
      'Take me back to the dashboard.',
      'Can you summarize what changed most recently?',
    ];
    final r = Random(DateTime.now().microsecondsSinceEpoch);
    pool.shuffle(r);
    return pool.take(4).toList();
  }

  Future<void> _refreshSuggestions() async {
    setState(() => _suggestions = _buildLocalSuggestions());
    try {
      final resp = await BackendApiService().aiSuggestions();
      final root = resp.data is Map ? Map<String, dynamic>.from(resp.data as Map) : {};
      final raw = root['suggestions'] ??
          (root['data'] is Map ? (root['data']['suggestions']) : null);
      final suggestions = raw is List
          ? raw.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList()
          : <String>[];
      if (!mounted) return;
      if (suggestions.isNotEmpty) {
        setState(() => _suggestions = suggestions);
      }
    } catch (_) {}
  }

  String _sanitizeAssistantText(String text) {
    var s = text;
    s = s.replaceAll('```', '');
    s = s.replaceAll('*', '');
    s = s.replaceAll('#', '');
    s = s.replaceAll('`', '');
    s = s.replaceAll(RegExp(r'^\s*terminal\s*\d+(?:\s*-\s*\d+)?\s*$', multiLine: true, caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'^\s*•\s+', multiLine: true), '- ');
    s = s.replaceAll(RegExp(r'^\s*\*\s+', multiLine: true), '- ');
    s = s.replaceAll(RegExp(r'[^\S\r\n]+'), ' ');
    return s.trim();
  }

  String _extractTitleFromPdfContent(String text) {
    final lines = text.split('\n');
    final limit = lines.length > 12 ? 12 : lines.length;
    for (var i = 0; i < limit; i++) {
      final raw = lines[i];
      final line = raw.trim();
      if (line.isEmpty) continue;
      final upper = line.toUpperCase();
      if (upper == 'PROJECT' || upper == 'SPRINT' || upper == 'SPRINT SUMMARY' || upper == 'TEAM MEMBERS') break;
      final m = RegExp(r'^(title|report title|suggested title)\s*:\s*(.+)$', caseSensitive: false).firstMatch(line);
      if (m != null) {
        final v = (m.group(2) ?? '').trim();
        if (v.isNotEmpty && !v.toLowerCase().contains('feedback')) return v;
      }
    }
    return '';
  }

  String _extractSprintNameFromPdfContent(String text) {
    final lines = text.split('\n');
    var inSprint = false;
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final upper = line.toUpperCase();
      if (upper == 'SPRINT') {
        inSprint = true;
        continue;
      }
      if (inSprint) {
        if (upper == 'SPRINT SUMMARY' || upper == 'TEAM MEMBERS' || upper == 'DELIVERABLES' || upper == 'SIGN-OFF NOTES' || upper == 'PROJECT') {
          break;
        }
        final m = RegExp(r'^(name|sprint name)\s*:\s*(.+)$', caseSensitive: false).firstMatch(line);
        if (m != null) {
          final v = (m.group(2) ?? '').trim();
          if (v.isNotEmpty) return v;
        }
      }
    }
    for (final raw in lines.take(20)) {
      final line = raw.trim();
      final m = RegExp(r'^(sprint)\s*:\s*(.+)$', caseSensitive: false).firstMatch(line);
      if (m != null) {
        final v = (m.group(2) ?? '').trim();
        if (v.isNotEmpty) return v;
      }
    }
    return '';
  }

  String _signaturePromptLine() {
    final options = <String>[
      'Before I finalize the PDF, let’s add your signature so the “Prepared By” section is complete.',
      'Quick check before export: I can include your digital signature in the “Prepared By” section. Add it now?',
      'One last step before I generate the PDF—please add your signature so the report is ready to send.',
    ];
    final r = Random(DateTime.now().microsecondsSinceEpoch);
    return options[r.nextInt(options.length)];
  }

  Future<Map<String, String?>> _ensureSignatureForAiExport() async {
    final signatureService = SignatureService(ApiClient());
    try {
      final sig = await signatureService.getDefaultSignature();
      if (sig != null && sig.signatureData.trim().isNotEmpty) {
        return {'signatureData': sig.signatureData, 'signatureType': sig.signatureType};
      }
    } catch (_) {}
    try {
      final sigs = await signatureService.getUserSignatures();
      UserSignature? pick;
      for (final s in sigs) {
        if (s.isDefault && s.signatureData.trim().isNotEmpty) {
          pick = s;
          break;
        }
      }
      if (pick == null) {
        for (final s in sigs) {
          if (s.signatureData.trim().isNotEmpty) {
            pick = s;
            break;
          }
        }
      }
      if (pick != null) {
        return {'signatureData': pick.signatureData, 'signatureType': pick.signatureType};
      }
    } catch (_) {}

    if (!mounted) return {};

    _messages.add({'role': 'assistant', 'content': _signaturePromptLine()});
    if (mounted) setState(() {});

    final key = GlobalKey<SignatureCaptureWidgetState>();
    final result = await showDialog<Map<String, String?>?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add your signature'),
          content: SizedBox(
            width: 520,
            child: SignatureCaptureWidget(
              key: key,
              allowSignatureReuse: true,
              showAuditInfo: false,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () async {
                final sig = await key.currentState?.getSignature();
                final signatureData = (sig ?? '').trim();
                if (signatureData.isEmpty) return;
                try {
                  await signatureService.saveSignature(signatureData, 'drawn', true);
                  if (context.mounted) {
                    Navigator.of(context).pop({'signatureData': signatureData, 'signatureType': 'drawn'});
                  }
                } catch (_) {
                  if (context.mounted) {
                    Navigator.of(context).pop({'signatureData': signatureData, 'signatureType': 'drawn'});
                  }
                }
              },
              child: const Text('Save & continue'),
            ),
          ],
        );
      },
    );
    return result ?? {};
  }

  bool _looksLikeFeedbackOrNotes(String value) {
    final t = value.trim();
    if (t.isEmpty) return true;
    if (t.contains('\n')) return true;
    if (t.length > 120) return true;
    final lower = t.toLowerCase();
    if (lower.contains('feedback')) return true;
    if (lower.contains('sign-off notes') || lower.contains('sign off notes') || lower.contains('signoff notes')) return true;
    if (RegExp(r'^(please|kindly|can you|could you|fix|remove|add|change|update|make sure|ensure)\b', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    if (RegExp(r'[.?!]$').hasMatch(t) &&
        RegExp(r'\b(fix|issue|issues|feedback)\b', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    return false;
  }

  bool _canGenerateAiSignOffReports() {
    final auth = AuthService();
    return auth.isSystemAdmin || auth.isDeliveryLead;
  }

  @override
  void initState() {
    super.initState();
    _refreshSuggestions();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    final maybeTitleFromUser = _extractTitleFromPdfContent(text);
    if (maybeTitleFromUser.isNotEmpty) {
      _lastConfirmedReportTitle = maybeTitleFromUser;
    }

    setState(() {
      _isSending = true;
      _messages.add({'role': 'user', 'content': text});
      _controller.clear();
      _suggestions = [];
    });

    try {
      debugPrint('AI Chat: sending messages...');
      final resp = await BackendApiService()
          .aiChat(_messages, temperature: 0.4, maxTokens: 500);
      debugPrint('AI Chat: response success=${resp.isSuccess}');
      final data = resp.data is Map ? Map<String, dynamic>.from(resp.data as Map) : {};
      debugPrint('AI Chat: data keys=${data.keys.toList()}');
      final content = (data['content'] ??
              (data['data'] is Map ? (data['data']['content'] ?? data['data']['message']) : null) ??
              data['message'])
          ?.toString()
          .trim();
      final actions = data['actions'];
      
      // Extract suggestions
      final rawSuggestions = data['suggestions'] ?? (data['data'] is Map ? data['data']['suggestions'] : null);
      debugPrint('AI Chat: rawSuggestions=$rawSuggestions');
      final suggestions = rawSuggestions is List ? rawSuggestions.cast<String>() : <String>[];

      bool navigated = false;
      bool silentNavigation = false;
      String? navigateRoute;

      if (resp.isSuccess && actions is List && actions.isNotEmpty) {
        for (final a in actions) {
          if (a is! Map) continue;
          final m = Map<String, dynamic>.from(a);
          final type = (m['type'] ?? '').toString().toLowerCase();
          if (type == 'navigate') {
            final route = (m['route'] ?? '').toString().trim();
            final silent = m['silent'] == true;
            if (route.isNotEmpty) {
              navigated = true;
              silentNavigation = silent;
              navigateRoute = route;
              break;
            }
          }
          if (type == 'export_pdf') {
            if (!_canGenerateAiSignOffReports()) {
              if (mounted) {
                setState(() {
                  _messages.add({
                    'role': 'assistant',
                    'content':
                        'Only Delivery Leads and System Admins can generate and export sign-off reports via FlowPilot.',
                  });
                });
              }
              continue;
            }
            final rawTitle = (m['title'] ?? 'Report').toString();
            final contentForPdf = (m['content'] ?? content ?? '').toString();
            if (contentForPdf.trim().isNotEmpty && mounted) {
              try {
                final sig = await _ensureSignatureForAiExport();
                final extracted = _extractTitleFromPdfContent(contentForPdf);
                final sprintName = _extractSprintNameFromPdfContent(contentForPdf);
                final candidates = <String>[extracted, _lastConfirmedReportTitle, rawTitle];
                var useTitle = 'Report';
                if (sprintName.trim().isNotEmpty) {
                  useTitle = sprintName.trim();
                  _lastConfirmedReportTitle = useTitle;
                } else {
                for (final c in candidates) {
                  final v = c.trim();
                  if (v.isEmpty) continue;
                  if (_looksLikeFeedbackOrNotes(v)) continue;
                  useTitle = v;
                  break;
                }
                }
                await ReportExportService().exportTextAsPDF(
                  title: useTitle,
                  content: contentForPdf,
                  useSignOffTemplate: true,
                  subtitle: 'SPRINT SIGN-OFF REPORT',
                  preparedBySignatureData: (sig['signatureData'] ?? '').trim().isEmpty ? null : sig['signatureData'],
                  preparedBySignatureType: (sig['signatureType'] ?? '').trim().isEmpty ? null : sig['signatureType'],
                );
              } catch (_) {}
            }
          }
        }
      }

      final shouldShowAssistantMessage = !(navigated && silentNavigation);
      if (shouldShowAssistantMessage) {
        final safeContent = resp.isSuccess
            ? (content?.isNotEmpty == true ? _sanitizeAssistantText(content!) : 'No response received.')
            : _sanitizeAssistantText(resp.error ?? 'Request failed.');
        final maybeTitleFromAssistant = _extractTitleFromPdfContent(safeContent);
        if (maybeTitleFromAssistant.isNotEmpty) {
          _lastConfirmedReportTitle = maybeTitleFromAssistant;
        }
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': safeContent,
          });
          _suggestions = suggestions;
        });
      } else {
        setState(() {
          _suggestions = suggestions;
        });
      }

      if (navigated && navigateRoute != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (silentNavigation) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Navigating…')),
            );
          }
          GoRouter.of(context).go(navigateRoute!);
        });
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

  @override
  Widget build(BuildContext context) {
    final visible = _messages.where((m) => m['role'] != 'system').toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('FlowPilot'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final m = visible[index];
                final role = (m['role'] ?? '').toLowerCase();
                final isUser = role == 'user';
                final content = m['content'] ?? '';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Card(
                      color: isUser
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(content),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_suggestions.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'Suggestions',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _suggestions.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final suggestion = _suggestions[index];
                        return ActionChip(
                          label: Text(suggestion),
                          // ignore: deprecated_member_use
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                          onPressed: () {
                            _controller.text = suggestion;
                            _send();
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask a question…',
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
            ),
          ),
        ],
      ),
    );
  }
}
