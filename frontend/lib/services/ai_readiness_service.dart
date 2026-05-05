import 'package:flutter/foundation.dart';
import '../models/release_readiness.dart';
import 'api_client.dart';

/// AI-powered Release Readiness Analysis Service
/// 
/// Uses AI to intelligently analyze deliverable readiness and provide:
/// - Smart status evaluation (Green/Amber/Red)
/// - Actionable recommendations
/// - Risk detection
/// - Missing item suggestions
class AIReadinessService {
  final ApiClient _apiClient = ApiClient();
  
  /// Analyze deliverable readiness with AI
  /// 
  /// Analyzes:
  /// - Definition of Done completion
  /// - Evidence quality and completeness
  /// - Sprint metrics and outcomes
  /// - Test coverage and quality gates
  /// - Documentation completeness
  /// - Risk factors
  Future<AIReadinessAnalysis> analyzeReadiness({
    required String deliverableId,
    required String deliverableTitle,
    required String deliverableDescription,
    required List<String> definitionOfDone,
    required List<String> evidenceLinks,
    required List<String> sprintIds,
    Map<String, dynamic>? sprintMetrics,
    String? knownLimitations,
  }) async {
    try {
      debugPrint('🤖 AI: Analyzing readiness for deliverable: $deliverableTitle');
      
      // Prepare analysis data
      final analysisData = {
        'deliverableId': deliverableId,
        'deliverableTitle': deliverableTitle,
        'deliverableDescription': deliverableDescription,
        'definitionOfDone': definitionOfDone,
        'evidenceLinks': evidenceLinks,
        'sprintIds': sprintIds,
        'sprintMetrics': sprintMetrics ?? {},
        'knownLimitations': knownLimitations,
      };
      
      // Call backend AI analysis endpoint
      debugPrint('🤖 AI: Calling backend endpoint: /release-readiness/analyze');
      final response = await _apiClient.post(
        '/release-readiness/analyze',
        body: analysisData,
      );
      
      debugPrint('🤖 AI: Response received - success: ${response.isSuccess}');
      if (response.error != null) {
        debugPrint('🤖 AI: Response error: ${response.error}');
      }
      
      if (response.isSuccess && response.data != null) {
        debugPrint('🤖 AI: Parsing AI analysis response...');
        return AIReadinessAnalysis.fromJson(response.data!);
      } else {
        // Fallback to local analysis if AI service unavailable
        debugPrint('⚠️ AI service unavailable, using local analysis');
        debugPrint('   Response success: ${response.isSuccess}');
        debugPrint('   Response data: ${response.data}');
        debugPrint('   Response error: ${response.error}');
        return _localAnalysis(analysisData);
      }
    } catch (e) {
      debugPrint('❌ AI analysis error: $e');
      // Fallback to local analysis
      return _localAnalysis({
        'deliverableTitle': deliverableTitle,
        'definitionOfDone': definitionOfDone,
        'evidenceLinks': evidenceLinks,
        'sprintIds': sprintIds,
      });
    }
  }
  
  /// Local fallback analysis (rule-based)
  AIReadinessAnalysis _localAnalysis(Map<String, dynamic> data) {
    final dod = (data['definitionOfDone'] as List?)?.cast<String>() ?? [];
    final evidence = (data['evidenceLinks'] as List?)?.cast<String>() ?? [];
    final sprints = (data['sprintIds'] as List?)?.cast<String>() ?? [];
    
    final issues = <String>[];
    final recommendations = <String>[];
    final risks = <String>[];
    
    // Analyze DoD
    if (dod.isEmpty) {
      issues.add('Definition of Done is empty');
      recommendations.add('Add at least 3-5 Definition of Done criteria');
    } else if (dod.length < 3) {
      issues.add('Definition of Done has fewer than 3 items');
      recommendations.add('Consider adding more DoD criteria for better quality assurance');
    }
    
    // Analyze evidence
    if (evidence.isEmpty) {
      issues.add('No evidence links provided');
      recommendations.add('Add evidence links: demo, repository, test results, documentation');
    } else {
      final lower = evidence.map((e) => e.toLowerCase()).toList();
      final hasDemo = lower.any((e) => e.contains('demo') || e.contains('video') || e.contains('live'));
      final hasRepo = lower.any((e) => e.contains('repo') || e.contains('github') || e.contains('gitlab') || e.contains('bitbucket'));
      final hasTests = lower.any((e) => e.contains('test') || e.contains('coverage') || e.contains('results') || e.contains('report'));
      final hasDocs = lower.any((e) => e.contains('doc') || e.contains('guide') || e.contains('readme') || e.contains('wiki'));
      
      // Evidence is present: do not block readiness on missing categories.
      // Provide recommendations to improve completeness instead of issues.
      if (!hasDemo) {
        recommendations.add('Consider adding a demo link or video');
      }
      if (!hasRepo) {
        recommendations.add('Consider adding repository link for code review');
      }
      if (!hasTests) {
        recommendations.add('Consider adding test results or coverage report');
      }
      if (!hasDocs) {
        recommendations.add('Consider adding user guide or technical documentation');
      }
    }
    
    // Analyze sprints
    if (sprints.isEmpty) {
      issues.add('No sprints linked to deliverable');
      recommendations.add('Link at least one sprint to show development progress');
    }
    
    // Calculate status
    ReadinessStatus status;
    if (issues.isEmpty) {
      status = ReadinessStatus.green;
    } else if (issues.length <= 2) {
      status = ReadinessStatus.amber;
    } else {
      status = ReadinessStatus.red;
    }
    
    return AIReadinessAnalysis(
      status: status,
      confidence: 0.85,
      issues: issues,
      recommendations: recommendations,
      risks: risks,
      missingItems: issues,
      priorityActions: recommendations.take(3).toList(),
      aiInsights: _generateInsights(issues, recommendations),
    );
  }
  
  String _generateInsights(List<String> issues, List<String> recommendations) {
    if (issues.isEmpty) {
      return '✅ All readiness criteria are met. This deliverable appears ready for client review.';
    }
    
    final criticalCount = issues.length;
    if (criticalCount >= 3) {
      return '⚠️ Multiple readiness gaps detected. Address the critical issues before submission to ensure quality and reduce client feedback cycles.';
    } else {
      return '💡 Minor improvements recommended. The deliverable is mostly ready, but addressing the suggested items will improve client confidence.';
    }
  }
  
  /// Get AI-powered suggestions for missing items
  Future<List<String>> getMissingItemSuggestions({
    required String deliverableTitle,
    required String deliverableDescription,
    required List<String> existingItems,
  }) async {
    try {
      final response = await _apiClient.post(
        '/release-readiness/suggest-items',
        body: {
          'deliverableTitle': deliverableTitle,
          'deliverableDescription': deliverableDescription,
          'existingItems': existingItems,
        },
      );
      
      if (response.isSuccess && response.data != null) {
        return (response.data!['suggestions'] as List).cast<String>();
      }
    } catch (e) {
      debugPrint('Error getting AI suggestions: $e');
    }
    
    // Fallback suggestions
    return [
      'Code review completed',
      'Unit tests passing (>80% coverage)',
      'Integration tests passing',
      'Documentation updated',
      'Demo prepared',
      'Performance benchmarks met',
    ];
  }
  
  /// Analyze sprint metrics for readiness
  Future<Map<String, dynamic>> analyzeSprintMetrics(List<Map<String, dynamic>> sprintMetrics) async {
    try {
      final response = await _apiClient.post(
        '/release-readiness/analyze-sprints',
        body: {'sprintMetrics': sprintMetrics},
      );
      
      if (response.isSuccess && response.data != null) {
        return response.data!;
      }
    } catch (e) {
      debugPrint('Error analyzing sprint metrics: $e');
    }
    
    // Fallback analysis
    return {
      'overallHealth': 'good',
      'concerns': [],
      'strengths': [],
    };
  }
}

/// AI Readiness Analysis Result
class AIReadinessAnalysis {
  final ReadinessStatus status;
  final double confidence; // 0.0 to 1.0
  final List<String> issues;
  final List<String> recommendations;
  final List<String> risks;
  final List<String> missingItems;
  final List<String> priorityActions;
  final String aiInsights;
  
  AIReadinessAnalysis({
    required this.status,
    required this.confidence,
    required this.issues,
    required this.recommendations,
    required this.risks,
    required this.missingItems,
    required this.priorityActions,
    required this.aiInsights,
  });
  
  factory AIReadinessAnalysis.fromJson(Map<String, dynamic> json) {
    return AIReadinessAnalysis(
      status: ReadinessStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ReadinessStatus.red,
      ),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.8,
      issues: (json['issues'] as List?)?.cast<String>() ?? [],
      recommendations: (json['recommendations'] as List?)?.cast<String>() ?? [],
      risks: (json['risks'] as List?)?.cast<String>() ?? [],
      missingItems: (json['missingItems'] as List?)?.cast<String>() ?? [],
      priorityActions: (json['priorityActions'] as List?)?.cast<String>() ?? [],
      aiInsights: json['aiInsights'] as String? ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'status': status.name,
      'confidence': confidence,
      'issues': issues,
      'recommendations': recommendations,
      'risks': risks,
      'missingItems': missingItems,
      'priorityActions': priorityActions,
      'aiInsights': aiInsights,
    };
  }
  
  bool get canProceed => status == ReadinessStatus.green || status == ReadinessStatus.amber;
  bool get isBlocked => status == ReadinessStatus.red;
  
  String get statusMessage {
    switch (status) {
      case ReadinessStatus.green:
        return '✅ Ready for Release - All criteria met';
      case ReadinessStatus.amber:
        return '⚠️ Ready with Issues - Some items need attention';
      case ReadinessStatus.red:
        return '❌ Not Ready - Critical issues must be resolved';
    }
  }
  
  // Get status color for UI
  int get statusColorValue {
    switch (status) {
      case ReadinessStatus.green:
        return 0xFF4CAF50; // Green
      case ReadinessStatus.amber:
        return 0xFFFF9800; // Orange
      case ReadinessStatus.red:
        return 0xFFF44336; // Red
    }
  }
}

