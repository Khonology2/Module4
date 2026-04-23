import 'package:flutter/material.dart';
import '../models/release_readiness.dart';
import '../services/ai_readiness_service.dart';
import '../theme/flownet_theme.dart';

/// AI-Powered Release Readiness Gate Widget
/// 
/// Displays:
/// - Green/Amber/Red status with AI analysis
/// - Actionable recommendations
/// - Missing items with AI suggestions
/// - Risk detection
/// - Blocking logic with internal approver option
class AIReadinessGateWidget extends StatefulWidget {
  final String deliverableId;
  final String deliverableTitle;
  final String deliverableDescription;
  final List<String> definitionOfDone;
  final List<String> evidenceLinks;
  final List<String> sprintIds;
  final Map<String, dynamic>? sprintMetrics;
  final String? knownLimitations;
  final Function(ReadinessStatus)? onStatusChanged;
  final Function(String)? onInternalApprovalRequested;

  const AIReadinessGateWidget({
    super.key,
    required this.deliverableId,
    required this.deliverableTitle,
    required this.deliverableDescription,
    required this.definitionOfDone,
    required this.evidenceLinks,
    required this.sprintIds,
    this.sprintMetrics,
    this.knownLimitations,
    this.onStatusChanged,
    this.onInternalApprovalRequested,
  });

  @override
  State<AIReadinessGateWidget> createState() => _AIReadinessGateWidgetState();
}

class _AIReadinessGateWidgetState extends State<AIReadinessGateWidget> {
  final AIReadinessService _aiService = AIReadinessService();
  AIReadinessAnalysis? _analysis;
  bool _isAnalyzing = false;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🤖 AI: ========================================');
    debugPrint('🤖 AI: WIDGET CREATED/INITIALIZED');
    debugPrint('🤖 AI: Deliverable ID: ${widget.deliverableId}');
    debugPrint('🤖 AI: Title: "${widget.deliverableTitle}"');
    debugPrint('🤖 AI: DoD: ${widget.definitionOfDone.length} items');
    debugPrint('🤖 AI: Evidence: ${widget.evidenceLinks.length} items');
    debugPrint('🤖 AI: Sprints: ${widget.sprintIds.length} items');
    debugPrint('🤖 AI: ========================================');
    
    // Delay initial analysis to ensure widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        debugPrint('🤖 AI: Post-frame callback - calling _analyzeReadiness()');
        _analyzeReadiness();
      } else {
        debugPrint('🤖 AI: Widget not mounted, skipping analysis');
      }
    });
  }

  @override
  void didUpdateWidget(AIReadinessGateWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint('🤖 AI: didUpdateWidget called');
    
    // Re-analyze if key data changed
    final titleChanged = oldWidget.deliverableTitle != widget.deliverableTitle;
    final dodChanged = oldWidget.definitionOfDone.length != widget.definitionOfDone.length ||
        !_listsEqual(oldWidget.definitionOfDone, widget.definitionOfDone);
    final evidenceChanged = oldWidget.evidenceLinks.length != widget.evidenceLinks.length ||
        !_listsEqual(oldWidget.evidenceLinks, widget.evidenceLinks);
    final sprintsChanged = oldWidget.sprintIds.length != widget.sprintIds.length ||
        !_listsEqual(oldWidget.sprintIds, widget.sprintIds);
    
    debugPrint('🤖 AI: Changes detected - Title: $titleChanged, DoD: $dodChanged, Evidence: $evidenceChanged, Sprints: $sprintsChanged');
    
    if (titleChanged || dodChanged || evidenceChanged || sprintsChanged) {
      debugPrint('🤖 AI: Widget data changed, re-analyzing...');
      _analyzeReadiness();
    } else {
      debugPrint('🤖 AI: No changes detected, skipping re-analysis');
    }
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _analyzeReadiness() async {
    debugPrint('🤖 AI: _analyzeReadiness() called');
    
    // Always analyze if there's any data, even just a title
    final hasTitle = widget.deliverableTitle.trim().isNotEmpty;
    final hasData = hasTitle || 
                    widget.definitionOfDone.isNotEmpty || 
                    widget.evidenceLinks.isNotEmpty ||
                    widget.sprintIds.isNotEmpty;
    
    debugPrint('🤖 AI: Data check - hasTitle: $hasTitle, hasData: $hasData');
    debugPrint('🤖 AI: Title: "${widget.deliverableTitle}"');
    debugPrint('🤖 AI: DoD: ${widget.definitionOfDone.length}, Evidence: ${widget.evidenceLinks.length}, Sprints: ${widget.sprintIds.length}');
    
    if (!hasData) {
      debugPrint('🤖 AI: ❌ Skipping analysis - no data provided yet');
      debugPrint('🤖 AI: (Title empty, DoD empty, Evidence empty, Sprints empty)');
      return;
    }

    debugPrint('🤖 AI: ========================================');
    debugPrint('🤖 AI: ✅ Starting readiness analysis...');
    debugPrint('🤖 AI: Title: "${widget.deliverableTitle}"');
    debugPrint('🤖 AI: DoD items: ${widget.definitionOfDone.length}');
    debugPrint('🤖 AI: Evidence links: ${widget.evidenceLinks.length}');
    debugPrint('🤖 AI: Sprints: ${widget.sprintIds.length}');
    debugPrint('🤖 AI: ========================================');

    setState(() => _isAnalyzing = true);

    try {
      final analysis = await _aiService.analyzeReadiness(
        deliverableId: widget.deliverableId,
        deliverableTitle: widget.deliverableTitle,
        deliverableDescription: widget.deliverableDescription,
        definitionOfDone: widget.definitionOfDone,
        evidenceLinks: widget.evidenceLinks,
        sprintIds: widget.sprintIds,
        sprintMetrics: widget.sprintMetrics,
        knownLimitations: widget.knownLimitations,
      );

      debugPrint('🤖 AI: ========================================');
      debugPrint('🤖 AI: Analysis complete!');
      debugPrint('🤖 AI: Status: ${analysis.status}');
      debugPrint('🤖 AI: Confidence: ${(analysis.confidence * 100).toStringAsFixed(1)}%');
      debugPrint('🤖 AI: Issues found: ${analysis.issues.length}');
      debugPrint('🤖 AI: Recommendations: ${analysis.recommendations.length}');
      debugPrint('🤖 AI: Risks: ${analysis.risks.length}');
      debugPrint('🤖 AI: Missing items: ${analysis.missingItems.length}');
      debugPrint('🤖 AI: ========================================');

      if (mounted) {
        setState(() {
          _analysis = analysis;
          _isAnalyzing = false;
        });

        widget.onStatusChanged?.call(analysis.status);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error analyzing readiness: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isAnalyzing = false);
        // Show error in UI
        _analysis = AIReadinessAnalysis(
          status: ReadinessStatus.red,
          confidence: 0.0,
          issues: ['Failed to analyze readiness: $e'],
          recommendations: ['Please try again or contact support'],
          risks: [],
          missingItems: [],
          priorityActions: [],
          aiInsights: 'Analysis service unavailable',
        );
        widget.onStatusChanged?.call(ReadinessStatus.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🤖 AI: build() called - isAnalyzing: $_isAnalyzing, analysis: ${_analysis != null ? "exists" : "null"}');
    
    if (_isAnalyzing) {
      debugPrint('🤖 AI: Showing loading indicator');
      return const Card(
        color: FlownetColors.graphiteGray,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('AI is analyzing readiness...'),
            ],
          ),
        ),
      );
    }

    if (_analysis == null && !_isAnalyzing) {
      // Show placeholder if no analysis yet and not analyzing
      debugPrint('🤖 AI: Showing placeholder - no analysis yet');
      debugPrint('🤖 AI: Title: "${widget.deliverableTitle}", hasData: ${widget.deliverableTitle.trim().isNotEmpty || widget.definitionOfDone.isNotEmpty || widget.evidenceLinks.isNotEmpty || widget.sprintIds.isNotEmpty}');
      return const Card(
        color: FlownetColors.graphiteGray,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'AI Release Readiness Gate',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Enter a deliverable title to start AI analysis',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    debugPrint('🤖 AI: Showing analysis results - Status: ${_analysis!.status}');
    return Card(
      color: FlownetColors.graphiteGray,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Status and Refresh Button
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(_analysis!.statusColorValue).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Color(_analysis!.statusColorValue), width: 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(_analysis!.status),
                          color: Color(_analysis!.statusColorValue),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _analysis!.statusMessage,
                          style: TextStyle(
                            color: Color(_analysis!.statusColorValue),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh AI Analysis',
                  onPressed: _isAnalyzing ? null : () {
                    debugPrint('🤖 AI: Manual refresh triggered');
                    _analyzeReadiness();
                  },
                ),
                IconButton(
                  icon: Icon(
                    _showDetails ? Icons.expand_less : Icons.expand_more,
                    color: FlownetColors.pureWhite,
                  ),
                  onPressed: () {
                    setState(() => _showDetails = !_showDetails);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // AI Insights
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FlownetColors.charcoalBlack,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.psychology, color: Colors.blue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _analysis!.aiInsights,
                      style: const TextStyle(
                        color: FlownetColors.pureWhite,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_showDetails) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Issues
              if (_analysis!.issues.isNotEmpty) ...[
                _buildSection(
                  'Issues Detected',
                  Icons.error_outline,
                  Colors.red,
                  _analysis!.issues,
                ),
                const SizedBox(height: 12),
              ],

              // Recommendations
              if (_analysis!.recommendations.isNotEmpty) ...[
                _buildSection(
                  'AI Recommendations',
                  Icons.lightbulb_outline,
                  Colors.amber,
                  _analysis!.recommendations,
                ),
                const SizedBox(height: 12),
              ],

              // Priority Actions
              if (_analysis!.priorityActions.isNotEmpty) ...[
                _buildSection(
                  'Priority Actions',
                  Icons.priority_high,
                  Colors.orange,
                  _analysis!.priorityActions,
                ),
                const SizedBox(height: 12),
              ],

              // Risks
              if (_analysis!.risks.isNotEmpty) ...[
                _buildSection(
                  'Risk Factors',
                  Icons.warning_amber,
                  Colors.red,
                  _analysis!.risks,
                ),
                const SizedBox(height: 12),
              ],

              // Confidence Score
              Row(
                children: [
                  const Icon(Icons.analytics, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'AI Confidence: ${(_analysis!.confidence * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: FlownetColors.pureWhite,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],

            // Blocking Logic
            if (_analysis!.isBlocked) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.block, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Submission Blocked',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This deliverable cannot be submitted until critical issues are resolved or acknowledged by an internal approver.',
                      style: TextStyle(color: FlownetColors.pureWhite, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        widget.onInternalApprovalRequested?.call(
                          'Requesting internal approval to proceed despite readiness issues',
                        );
                      },
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Request Internal Approval'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_analysis!.status == ReadinessStatus.amber) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange, width: 1),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You can proceed, but addressing the recommendations will improve quality.',
                        style: TextStyle(color: FlownetColors.pureWhite, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Color color, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 26, bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: FlownetColors.pureWhite)),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: FlownetColors.pureWhite,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  IconData _getStatusIcon(ReadinessStatus status) {
    switch (status) {
      case ReadinessStatus.green:
        return Icons.check_circle;
      case ReadinessStatus.amber:
        return Icons.warning;
      case ReadinessStatus.red:
        return Icons.cancel;
    }
  }
}

