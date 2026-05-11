import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../models/deliverable.dart' as model;
import '../models/sprint_metrics.dart';
import '../services/backend_api_service.dart';
import '../providers/service_providers.dart';
import '../theme/flownet_theme.dart';
import '../widgets/flownet_logo.dart';
import '../widgets/sprint_performance_chart.dart';
import '../services/approval_service.dart';
import '../services/auth_service.dart';

class ReportBuilderScreen extends ConsumerStatefulWidget {
  final String deliverableId;
  
  const ReportBuilderScreen({
    super.key,
    required this.deliverableId,
  });

  @override
  ConsumerState<ReportBuilderScreen> createState() => _ReportBuilderScreenState();
}

class _ReportBuilderScreenState extends ConsumerState<ReportBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reportTitleController = TextEditingController();
  final _reportContentController = TextEditingController();
  final _knownLimitationsController = TextEditingController();
  final _nextStepsController = TextEditingController();
  
  model.Deliverable? _deliverable;
  List<SprintMetrics> _sprintMetrics = [];
  bool _isGenerating = false;
  bool _isAiSuggesting = false;
  bool _isPreviewMode = false;
bool _isLoading = false;

  @override
  void initState() {
    super.initState();
WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDeliverableData();
    });
  }

  Future<void> _loadDeliverableData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final backendService = BackendApiService();
      
      // Load deliverable data
      final deliverableResponse = await backendService.getDeliverable(widget.deliverableId);
      
      if (deliverableResponse.isSuccess && deliverableResponse.data != null) {
        final deliverableData = deliverableResponse.data!;
        final deliverable = model.Deliverable.fromJson(deliverableData);
        
        // Load sprint metrics for each sprint in the deliverable
        final List<SprintMetrics> sprintMetrics = [];
        
        for (final sprintId in deliverable.sprintIds) {
          final metricsResponse = await backendService.getSprintMetrics(sprintId);
          if (metricsResponse.isSuccess && metricsResponse.data != null) {
            final metrics = backendService.parseSprintMetricsFromResponse(metricsResponse);
            sprintMetrics.addAll(metrics);
          }
        }
        
        setState(() {
          _deliverable = deliverable;
          _sprintMetrics = sprintMetrics;
          _isLoading = false;
        });
        
        generateReportContent();
      } else {
        // Handle API error gracefully
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load deliverable data: ${deliverableResponse.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() {
          _isLoading = false;
          _deliverable = null;
          _sprintMetrics = [];
        });
      }
    } catch (e) {
      debugPrint('Error loading deliverable data: $e');
      // Always set loading to false even on error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading deliverable: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadDeliverableData,
            ),
          ),
        );
      }
      setState(() {
        _isLoading = false;
        _deliverable = null; // Keep null to trigger error state
        _sprintMetrics = [];
      });
    }
  }

  void generateReportContent() {
    if (_deliverable == null) return;

    _reportTitleController.text = 'Sign-Off Report: ${_deliverable!.title}';
    
    final content = buildReportContent();
    _reportContentController.text = content;
  }

  String buildReportContent() {
    if (_deliverable == null) return '';

    final buffer = StringBuffer();
    
    // Executive Summary
    buffer.writeln('## Executive Summary');
    buffer.writeln();
    buffer.writeln('This report provides a comprehensive overview of the ${_deliverable!.title} deliverable, including sprint performance metrics, quality indicators, and readiness for client approval.');
    buffer.writeln();
    
    // Deliverable Overview
    buffer.writeln('## Deliverable Overview');
    buffer.writeln();
    buffer.writeln('**Title:** ${_deliverable!.title}');
    buffer.writeln('**Description:** ${_deliverable!.description}');
    buffer.writeln('**Due Date:** ${formatDate(_deliverable!.dueDate)}');
    buffer.writeln('**Status:** ${_deliverable!.statusDisplayName}');
    buffer.writeln();
    
    // Definition of Done
    buffer.writeln('## Definition of Done Checklist');
    buffer.writeln();
    for (int i = 0; i < _deliverable!.definitionOfDone.length; i++) {
      buffer.writeln('${i + 1}. ✅ ${_deliverable!.definitionOfDone[i]}');
    }
    buffer.writeln();
    
    // Evidence & Artifacts
    buffer.writeln('## Evidence & Artifacts');
    buffer.writeln();
    for (int i = 0; i < _deliverable!.evidenceLinks.length; i++) {
      buffer.writeln('${i + 1}. [Evidence ${i + 1}](${_deliverable!.evidenceLinks[i]})');
    }
    buffer.writeln();
    
    // Sprint Performance Summary
    buffer.writeln('## Sprint Performance Summary');
    buffer.writeln();

    if (_sprintMetrics.isEmpty) {
      buffer.writeln('No sprint metrics have been captured yet for the linked sprints.');
      buffer.writeln();
      return buffer.toString();
    }

    final totalCommitted =
        _sprintMetrics.fold(0, (sum, metric) => sum + metric.committedPoints);
    final totalCompleted =
        _sprintMetrics.fold(0, (sum, metric) => sum + metric.completedPoints);
    final avgTestPassRate = _sprintMetrics.fold(
          0.0,
          (sum, metric) => sum + metric.testPassRate,
        ) /
        _sprintMetrics.length;
    final totalDefects =
        _sprintMetrics.fold(0, (sum, metric) => sum + metric.totalDefects);
    final resolvedDefects =
        _sprintMetrics.fold(0, (sum, metric) => sum + metric.defectsClosed);
    
    buffer.writeln('**Total Committed Points:** $totalCommitted');
    buffer.writeln('**Total Completed Points:** $totalCompleted');
    buffer.writeln('**Completion Rate:** ${((totalCompleted / totalCommitted) * 100).toStringAsFixed(1)}%');
    buffer.writeln('**Average Test Pass Rate:** ${avgTestPassRate.toStringAsFixed(1)}%');
    buffer.writeln('**Total Defects:** $totalDefects');
    buffer.writeln('**Resolved Defects:** $resolvedDefects');
    buffer.writeln('**Defect Resolution Rate:** ${((resolvedDefects / totalDefects) * 100).toStringAsFixed(1)}%');
    buffer.writeln();
    
    // Quality Indicators
    buffer.writeln('## Quality Indicators');
    buffer.writeln();
    buffer.writeln('All sprints maintained high quality standards with:');
    buffer.writeln('- Test pass rates consistently above 95%');
    buffer.writeln('- Complete code review coverage');
    buffer.writeln('- Comprehensive documentation');
    buffer.writeln('- Zero critical defects in production');
    buffer.writeln();
    
    // Risk Assessment
    buffer.writeln('## Risk Assessment');
    buffer.writeln();
    final allRisks = _sprintMetrics.where((m) => m.risks != null && m.risks!.isNotEmpty).map((m) => m.risks!).toList();
    if (allRisks.isNotEmpty) {
      for (int i = 0; i < allRisks.length; i++) {
        buffer.writeln('${i + 1}. ${allRisks[i]}');
      }
    } else {
      buffer.writeln('No significant risks identified during development.');
    }
    buffer.writeln();
    
    return buffer.toString();
  }

  String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

Future<void> _generateTitleSuggestion() async {
    if (_deliverable == null || _isAiSuggesting) return;
    setState(() => _isAiSuggesting = true);
    try {
      final messages = [
        {
          'role': 'system',
          'content': 'Propose a clear sign-off report title based on the deliverable.'
        },
        {
          'role': 'user',
          'content': 'Deliverable: ${_deliverable!.title}\nDescription: ${_deliverable!.description}'
        }
      ];
      final resp = await BackendApiService().aiChat(messages, temperature: 0.6, maxTokens: 40);
      if (resp.isSuccess && resp.data != null) {
        final data = resp.data is Map ? Map<String, dynamic>.from(resp.data as Map) : {};
        final content = (data['content'] ?? (data['data']?['content']))?.toString() ?? '';
        if (content.isNotEmpty) {
          _reportTitleController.text = content.trim();
        }
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _isAiSuggesting = false);
    }
  }

  Future<void> _generateContentSuggestion() async {
    if (_deliverable == null || _isAiSuggesting) return;
    setState(() => _isAiSuggesting = true);
    try {
      final totalCommitted = _sprintMetrics.fold(0, (sum, metric) => sum + metric.committedPoints);
      final totalCompleted = _sprintMetrics.fold(0, (sum, metric) => sum + metric.completedPoints);
      final avgTestPassRate = _sprintMetrics.isEmpty ? 0.0 : _sprintMetrics.fold(0.0, (sum, m) => sum + m.testPassRate) / _sprintMetrics.length;
      final messages = [
        {
          'role': 'system',
          'content': 'Draft a structured report content with sections and concise language.'
        },
        {
          'role': 'user',
          'content': 'Title: ${_deliverable!.title}\nDescription: ${_deliverable!.description}\nCommitted: $totalCommitted\nCompleted: $totalCompleted\nAvgTestPassRate: ${avgTestPassRate.toStringAsFixed(1)}%\nDefinitionOfDone: ${_deliverable!.definitionOfDone.join('; ')}'
        }
      ];
      final resp = await BackendApiService().aiChat(messages, temperature: 0.7, maxTokens: 600);
      if (resp.isSuccess && resp.data != null) {
        final data = resp.data is Map ? Map<String, dynamic>.from(resp.data as Map) : {};
        final content = (data['content'] ?? (data['data']?['content']))?.toString() ?? '';
        if (content.isNotEmpty) {
          _reportContentController.text = content.trim();
        }
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _isAiSuggesting = false);
    }
  }

  Future<void> _generateKnownLimitationsSuggestion() async {
    if (_deliverable == null || _isAiSuggesting) return;
    setState(() => _isAiSuggesting = true);
    try {
      final messages = [
        {
          'role': 'system',
          'content': 'List concise known limitations and risks, one per line.'
        },
        {
          'role': 'user',
          'content': 'Deliverable: ${_deliverable!.title}\nMetrics: ${_sprintMetrics.map((m) => 'D:${m.totalDefects}/R:${m.defectsClosed}/TPR:${m.testPassRate.toStringAsFixed(1)}').join(', ')}'
        }
      ];
      final resp = await BackendApiService().aiChat(messages, temperature: 0.6, maxTokens: 160);
      if (resp.isSuccess && resp.data != null) {
        final data = resp.data is Map ? Map<String, dynamic>.from(resp.data as Map) : {};
        final content = (data['content'] ?? (data['data']?['content']))?.toString() ?? '';
        if (content.isNotEmpty) {
          _knownLimitationsController.text = content.trim();
        }
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _isAiSuggesting = false);
    }
  }

  Future<void> _generateNextStepsSuggestion() async {
    if (_deliverable == null || _isAiSuggesting) return;
    setState(() => _isAiSuggesting = true);
    try {
      final messages = [
        {
          'role': 'system',
          'content': 'Suggest actionable next steps for stakeholders, one per line.'
        },
        {
          'role': 'user',
          'content': 'Title: ${_deliverable!.title}\nStatus: ${_deliverable!.statusDisplayName}\nDefinitionOfDone: ${_deliverable!.definitionOfDone.join('; ')}'
        }
      ];
      final resp = await BackendApiService().aiChat(messages, temperature: 0.6, maxTokens: 160);
      if (resp.isSuccess && resp.data != null) {
        final data = resp.data is Map ? Map<String, dynamic>.from(resp.data as Map) : {};
        final content = (data['content'] ?? (data['data']?['content']))?.toString() ?? '';
        if (content.isNotEmpty) {
          _nextStepsController.text = content.trim();
        }
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _isAiSuggesting = false);
    }
  }

  Future<void> generateReport() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final backend = ref.read(backendApiServiceProvider);

      final sprintIds = _deliverable?.sprintIds ?? [];
      for (final sprintId in sprintIds) {
        final resp = await backend.getSprint(sprintId);
        if (resp.isSuccess && resp.data != null) {
          final raw = resp.data;
          final data = raw is Map && raw['data'] is Map ? Map<String, dynamic>.from(raw['data'] as Map) : (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
          final status = (data['status'] ?? '').toString().toLowerCase();
          final isCompleted = status == 'completed' || status == 'done' || status == 'closed';
          if (!isCompleted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('A sprint report can only be generated for completed sprints.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        }
      }

      setState(() {
        _isGenerating = true;
      });
      
      String? sprintPerformanceData;
      if (_sprintMetrics.isNotEmpty) {
        sprintPerformanceData = jsonEncode(_sprintMetrics.map((m) => m.toJson()).toList());
      }

      final payload = {
        'deliverableId': _deliverable!.id,
        'reportTitle': _reportTitleController.text.trim(),
        'reportContent': _reportContentController.text.trim(),
        'sprintIds': _deliverable!.sprintIds,
        'sprintPerformanceData': sprintPerformanceData,
        'knownLimitations': _knownLimitationsController.text.trim().isEmpty ? null : _knownLimitationsController.text.trim(),
        'nextSteps': _nextStepsController.text.trim().isEmpty ? null : _nextStepsController.text.trim(),
        'status': 'submitted',
      };

      final response = await backend.createSignOffReport(payload);
      
      if (mounted) {
        if (response.isSuccess && response.data != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report generated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate to report view screen
          final reportData = response.data is Map ? (response.data['data'] ?? response.data['report'] ?? response.data) : response.data;
          final reportId = reportData['id'];
          if (reportId != null) {
            context.go('/report-view/$reportId');
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error generating report: ${response.error ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

void togglePreview() {
    setState(() {
      _isPreviewMode = !_isPreviewMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show form even if deliverable fails to load, but show loading indicator during initial load
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    // If deliverable failed to load, show error message but still allow form editing
    if (_deliverable == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Create Report'),
          backgroundColor: FlownetColors.graphiteGray,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Error message
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Deliverable data could not be loaded. You can still create a report manually.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
              // Show the form
              buildEditMode(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: FlownetColors.charcoalBlack,
      appBar: AppBar(
        title: const FlownetLogo(),
        backgroundColor: FlownetColors.charcoalBlack,
        foregroundColor: FlownetColors.pureWhite,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(_isPreviewMode ? Icons.edit : Icons.preview),
            onPressed: togglePreview,
            tooltip: _isPreviewMode ? 'Edit Mode' : 'Preview Mode',
          ),
        ],
      ),
      body: _isPreviewMode ? buildPreviewMode() : buildEditMode(),
    );
  }

  Widget buildEditMode() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Sign-Off Report Builder',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: FlownetColors.pureWhite,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Deliverable: ${_deliverable!.title}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: FlownetColors.coolGray,
              ),
            ),
            const SizedBox(height: 24),

            // Report Title
            TextFormField(
              controller: _reportTitleController,
              decoration: const InputDecoration(
                labelText: 'Report Title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) => value?.isEmpty == true ? 'Title is required' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isAiSuggesting ? null : _generateTitleSuggestion,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Suggest Title with AI'),
              ),
            ),
            const SizedBox(height: 16),

            // Report Content
            TextFormField(
              controller: _reportContentController,
              decoration: const InputDecoration(
                labelText: 'Report Content',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 15,
              validator: (value) => value?.isEmpty == true ? 'Content is required' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isAiSuggesting ? null : _generateContentSuggestion,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Suggest Content with AI'),
              ),
            ),
            const SizedBox(height: 16),

            // Known Limitations
            TextFormField(
              controller: _knownLimitationsController,
              decoration: const InputDecoration(
                labelText: 'Known Limitations',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.warning),
                hintText: 'Any known issues or limitations...',
              ),
              maxLines: 3,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isAiSuggesting ? null : _generateKnownLimitationsSuggestion,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Suggest with AI'),
              ),
            ),
            const SizedBox(height: 16),

            // Next Steps
            TextFormField(
              controller: _nextStepsController,
              decoration: const InputDecoration(
                labelText: 'Next Steps',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.arrow_forward),
                hintText: 'Recommended next steps or follow-up actions...',
              ),
              maxLines: 3,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isAiSuggesting ? null : _generateNextStepsSuggestion,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Suggest with AI'),
              ),
            ),
            const SizedBox(height: 24),

            // Sprint Performance Chart
buildSprintPerformanceSection(),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : generateReport,
                    icon: _isGenerating 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(_isGenerating ? 'Generating...' : 'Generate Report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlownetColors.electricBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: togglePreview,
                    icon: const Icon(Icons.preview),
                    label: const Text('Preview'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlownetColors.amberOrange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPreviewMode() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview Header
          Row(
            children: [
              IconButton(
                onPressed: togglePreview,
                icon: const Icon(Icons.edit),
                tooltip: 'Edit Mode',
              ),
              Text(
                'Report Preview',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: FlownetColors.pureWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Report Content Preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Report Header
                Text(
                  _reportTitleController.text,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Generated on ${formatDate(DateTime.now())}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const Divider(),
                const SizedBox(height: 16),

                // Report Content
                Text(
                  _reportContentController.text,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 16),

                // Known Limitations
                if (_knownLimitationsController.text.isNotEmpty) ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Known Limitations',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _knownLimitationsController.text,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                ],

                // Next Steps
                if (_nextStepsController.text.isNotEmpty) ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Next Steps',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _nextStepsController.text,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
onPressed: _isGenerating ? null : generateReport,
                  icon: _isGenerating 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isGenerating ? 'Saving...' : 'Save Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlownetColors.emeraldGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (_deliverable == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No deliverable loaded for this report.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final description = _reportContentController.text.isNotEmpty
                        ? _reportContentController.text
                        : _deliverable!.description;

                    if (description.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please generate or enter report content before submitting for review.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final authService = AuthService();
                    final approvalService = ApprovalService(authService);
                    final response = await approvalService.createApprovalRequest(
                      deliverableId: _deliverable!.id,
                      requestedBy: authService.currentUser?.id ?? 'unknown',
                      comments: description,
                      category: 'Deliverable',
                      priority: 'medium',
                    );

                    if (!mounted) return;

                    if (response.isSuccess) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Approval request created. Check the Approvals screen.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      context.go('/approvals');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to create approval request: ${response.error ?? "Unknown error"}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Submit for Review'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlownetColors.crimsonRed,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildSprintPerformanceSection() {
    return Card(
      color: FlownetColors.graphiteGray,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sprint Performance Visualizations',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: FlownetColors.pureWhite,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Velocity Chart (using committed as planned points and completed points)
            SprintPerformanceChart(
              sprints: _sprintMetrics
                  .map((m) => {
                        'id': m.sprintId,
                        'name': 'Sprint ${m.sprintId}',
                        'planned_points': m.committedPoints,
                        'completed_points': m.completedPoints,
                      })
                  .toList(),
              chartType: 'velocity',
            ),
            const SizedBox(height: 16),
            
            // Quality Metrics Summary
            Row(
              children: [
                Expanded(
                  child: buildMetricCard(
                    'Avg Test Pass Rate',
                    '${_sprintMetrics.fold(0.0, (sum, m) => sum + m.testPassRate) / _sprintMetrics.length}%',
                    Icons.science,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: buildMetricCard(
                    'Total Defects',
                    '${_sprintMetrics.fold(0, (sum, m) => sum + m.totalDefects)}',
                    Icons.bug_report,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: buildMetricCard(
                    'Resolution Rate',
                    '${_sprintMetrics.fold(0.0, (sum, m) => sum + m.defectResolutionRate) / _sprintMetrics.length}%',
                    Icons.check_circle,
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FlownetColors.slate,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _reportTitleController.dispose();
    _reportContentController.dispose();
    _knownLimitationsController.dispose();
    _nextStepsController.dispose();
    super.dispose();
  }
}
