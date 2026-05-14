import 'dart:async';

import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';
import '../theme/flownet_theme.dart';

/// Returned from [showAiProjectGenerateDialog] when the user taps **Done** after a successful run.
class AiProjectDraftResult {
  final String projectTitle;
  final String description;
  final String status;
  final String priority;
  final String projectType;
  final List<String> tags;

  const AiProjectDraftResult({
    required this.projectTitle,
    required this.description,
    required this.status,
    required this.priority,
    required this.projectType,
    required this.tags,
  });
}

/// Create Project flow: enter a title, run AI, see progress, apply on **Done**.
Future<AiProjectDraftResult?> showAiProjectGenerateDialog(
  BuildContext context, {
  required BackendApiService backend,
}) {
  return showDialog<AiProjectDraftResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _AiProjectGenerateDialog(backend: backend),
  );
}

class _AiProjectGenerateDialog extends StatefulWidget {
  final BackendApiService backend;

  const _AiProjectGenerateDialog({required this.backend});

  @override
  State<_AiProjectGenerateDialog> createState() => _AiProjectGenerateDialogState();
}

class _AiProjectGenerateDialogState extends State<_AiProjectGenerateDialog> {
  static const Color _brandRed = Color(0xFFD70E0E);

  static const List<String> _progressStages = [
    'Analyzing project title…',
    'Drafting description…',
    'Selecting status & priority…',
    'Choosing project type…',
    'Suggesting tags…',
    'Finalizing draft…',
  ];

  final TextEditingController _titleController = TextEditingController();
  Timer? _stageTimer;
  int _stageIndex = 0;

  bool _isGenerating = false;
  bool _isComplete = false;
  String? _errorMessage;
  AiProjectDraftResult? _result;

  @override
  void dispose() {
    _stageTimer?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  void _startStageTicker() {
    _stageTimer?.cancel();
    _stageIndex = 0;
    _stageTimer = Timer.periodic(const Duration(milliseconds: 1300), (_) {
      if (!mounted || !_isGenerating) return;
      setState(() {
        _stageIndex = (_stageIndex + 1) % _progressStages.length;
      });
    });
  }

  void _stopStageTicker() {
    _stageTimer?.cancel();
    _stageTimer = null;
  }

  Future<void> _runGenerate() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Enter or paste a project name first.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isGenerating = true;
      _isComplete = false;
      _result = null;
    });
    _startStageTicker();

    try {
      final resp = await widget.backend.generateProjectDraftWithAi(title);
      _stopStageTicker();
      if (!mounted) return;

      if (!resp.isSuccess || resp.data == null) {
        setState(() {
          _isGenerating = false;
          _errorMessage = resp.error ?? 'AI request failed.';
        });
        return;
      }

      if (resp.data is! Map) {
        setState(() {
          _isGenerating = false;
          _errorMessage = 'Unexpected response from server.';
        });
        return;
      }

      final map = Map<String, dynamic>.from(resp.data as Map);
      final description = (map['description'] ?? '').toString();
      final status = (map['status'] ?? 'planning').toString();
      final priority = (map['priority'] ?? 'medium').toString();
      final projectType = (map['projectType'] ?? 'software').toString();
      final tagsRaw = map['tags'];
      final List<String> tags = [];
      if (tagsRaw is List) {
        for (final t in tagsRaw) {
          final s = t.toString().trim();
          if (s.isNotEmpty) tags.add(s);
        }
      }

      setState(() {
        _isGenerating = false;
        _isComplete = true;
        _result = AiProjectDraftResult(
          projectTitle: title,
          description: description,
          status: status,
          priority: priority,
          projectType: projectType,
          tags: tags,
        );
      });
    } catch (e) {
      _stopStageTicker();
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _errorMessage = 'Something went wrong: $e';
      });
    }
  }

  void _onDone() {
    final r = _result;
    if (r != null) {
      Navigator.of(context).pop(r);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF2B2D33) : const Color(0xFFF4F4F6);

    return AlertDialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Expanded(
            child: Text(
              'AI project assistant',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? FlownetColors.pureWhite : Colors.black87,
              ),
            ),
          ),
          if (!_isGenerating)
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ClipOval(
                  child: Container(
                    width: 88,
                    height: 88,
                    color: isDark ? Colors.black26 : Colors.white,
                    child: Image.asset(
                      'assets/Ai_Avatar.gif',
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.smart_toy_outlined,
                        size: 44,
                        color: _brandRed.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!_isGenerating && !_isComplete) ...[
                TextField(
                  controller: _titleController,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _runGenerate(),
                  decoration: InputDecoration(
                    labelText: 'Project name',
                    hintText: 'Paste or type the project title',
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                ),
              ],
              if (_isGenerating) ...[
                const SizedBox(height: 8),
                Text(
                  _progressStages[_stageIndex],
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                ),
              ],
              if (_isComplete && _result != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Draft ready. Tap Done to fill the form, then review and adjust any fields.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_isGenerating)
          TextButton(
            onPressed: () {
              _stopStageTicker();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        if (!_isGenerating && !_isComplete) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _brandRed,
              foregroundColor: Colors.white,
            ),
            onPressed: _runGenerate,
            icon: const Icon(Icons.auto_awesome, size: 20),
            label: const Text('Generate'),
          ),
        ],
        if (_isComplete)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _brandRed,
              foregroundColor: Colors.white,
            ),
            onPressed: _onDone,
            child: const Text('Done'),
          ),
      ],
    );
  }
}
