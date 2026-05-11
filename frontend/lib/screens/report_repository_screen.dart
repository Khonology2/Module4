import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/sign_off_report.dart';
import '../models/repository_file.dart';
import '../models/user_role.dart';
import '../services/document_service.dart';
import '../services/auth_service.dart';
import '../services/sign_off_report_service.dart';
import '../services/backend_api_service.dart';
import '../services/report_export_service.dart';
import '../services/realtime_service.dart';
import '../theme/flownet_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/document_preview_widget.dart';
import '../widgets/signature_capture_widget.dart';
import 'report_editor_screen.dart';
import 'client_review_workflow_screen.dart';

class ReportRepositoryScreen extends ConsumerStatefulWidget {
  const ReportRepositoryScreen({super.key});

  @override
  ConsumerState<ReportRepositoryScreen> createState() => _ReportRepositoryScreenState();
}

class _ReportRepositoryScreenState extends ConsumerState<ReportRepositoryScreen> {
  static const Color _reportsAccentBlue = Color(0xFF0623B1);

  List<SignOffReport> _reports = [];
  List<RepositoryFile> _reportDocuments = [];
  String _selectedFilter = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final DocumentService _documentService = DocumentService(AuthService());
  final SignOffReportService _reportService = SignOffReportService(AuthService());
  final ReportExportService _exportService = ReportExportService();
  bool _isLoading = false;

  // Advanced filters
  String? _selectedProjectId;
  String? _selectedSprintId;
  String? _selectedDeliverableId;
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _showAdvancedFilters = false;

  // Cached filter options (loaded from backend)
  final List<Map<String, dynamic>> _projects = [];
  final List<Map<String, dynamic>> _sprints = [];
  final List<Map<String, dynamic>> _deliverables = [];

  Future<void> _startSprintBasedReportCreation() async {
    final backend = BackendApiService();
    List<Map<String, dynamic>> sprints = const <Map<String, dynamic>>[];
    String? selectedSprintId;
    String? selectedSprintName;
    bool loading = true;
    String? loadError;

    await showDialog<void>(
      context: context,
      builder: (context) {
        Future<void> load() async {
          try {
            final resp = await backend.getSprints(limit: 200);
            if (!resp.isSuccess || resp.data == null) {
              throw Exception(resp.error ?? 'Failed to load sprints');
            }
            final raw = resp.data;
            final list = raw is List ? raw : (raw is Map ? (raw['data'] ?? raw['sprints'] ?? raw['items'] ?? []) : const <dynamic>[]);
            final parsed = (list as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();

            bool isCompletedStatus(String v) {
              final n = v.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
              return n == 'completed' || n == 'done' || n == 'closed';
            }

            parsed.sort((a, b) {
              final aId = int.tryParse((a['id'] ?? '').toString()) ?? 0;
              final bId = int.tryParse((b['id'] ?? '').toString()) ?? 0;
              return bId.compareTo(aId);
            });

            sprints = parsed.where((s) => isCompletedStatus((s['status'] ?? '').toString())).toList();
            if (sprints.isNotEmpty) {
              selectedSprintId = sprints.first['id']?.toString();
              selectedSprintName = sprints.first['name']?.toString();
            }
            loadError = null;
          } catch (e) {
            loadError = e.toString();
          } finally {
            loading = false;
          }
        }

        return StatefulBuilder(
          builder: (context, setLocalState) {
            if (loading) {
              Future<void>(() async {
                await load();
                if (!context.mounted) return;
                setLocalState(() {});
              });
            }

            return AlertDialog(
              title: const Text('Create Sprint Sign-Off Report'),
              content: SizedBox(
                width: 480,
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : (loadError != null
                        ? Text('Failed to load sprints: $loadError')
                        : (sprints.isEmpty
                            ? const Text('No completed sprints found. Complete a sprint first to generate a sign-off report.')
                            : DropdownButtonFormField<String>(
                                initialValue: selectedSprintId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Completed Sprint',
                                  border: OutlineInputBorder(),
                                ),
                                selectedItemBuilder: (context) {
                                  return sprints.map((s) {
                                    final name = (s['name'] ?? 'Sprint').toString();
                                    final project = s['project'] is Map ? (s['project']['name'] ?? '').toString() : '';
                                    final label = project.trim().isNotEmpty ? '$project — $name' : name;
                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
                                    );
                                  }).toList();
                                },
                                items: sprints.map((s) {
                                  final id = (s['id'] ?? '').toString();
                                  final name = (s['name'] ?? 'Sprint').toString();
                                  final project = s['project'] is Map ? (s['project']['name'] ?? '').toString() : '';
                                  final label = project.trim().isNotEmpty ? '$project — $name' : name;
                                  return DropdownMenuItem<String>(
                                    value: id,
                                    child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  setLocalState(() {
                                    selectedSprintId = v;
                                    final pick = sprints.firstWhere(
                                      (s) => (s['id'] ?? '').toString() == (v ?? ''),
                                      orElse: () => const <String, dynamic>{},
                                    );
                                    selectedSprintName = pick.isNotEmpty ? pick['name']?.toString() : null;
                                  });
                                },
                              ))),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: (loading || loadError != null || (selectedSprintId ?? '').trim().isEmpty)
                      ? null
                      : () {
                          final sid = (selectedSprintId ?? '').trim();
                          final name = (selectedSprintName ?? '').trim();
                          Navigator.of(context).pop();
                          final q = name.isNotEmpty ? '?name=${Uri.encodeComponent(name)}' : '';
                          context.go('/sprint-report/$sid$q');
                        },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadReports();
    _loadReportDocuments();
    _loadFilterOptions();
    Future.microtask(() async {
      try {
        await AuthService().initialize();
      } catch (_) {}
      try {
        final token = AuthService().accessToken;
        if (token != null && token.isNotEmpty) {
          await RealtimeService().initialize(authToken: token);
          RealtimeService().on('document_uploaded', (data) {
            try {
              final doc = RepositoryFile.fromJson(Map<String, dynamic>.from(data));
              setState(() {
                _reportDocuments = [doc, ..._reportDocuments];
              });
            } catch (_) {
              _loadReportDocuments();
            }
          });
          RealtimeService().on('document_deleted', (data) {
            try {
              final id = (data is Map && data['id'] != null) ? data['id'].toString() : null;
              if (id != null) {
                setState(() {
                  _reportDocuments.removeWhere((d) => d.id == id);
                });
              } else {
                _loadReportDocuments();
              }
            } catch (_) {
              _loadReportDocuments();
            }
          });
          RealtimeService().on('report_created', (_) => _loadReports());
          RealtimeService().on('report_submitted', (_) => _loadReports());
          RealtimeService().on('report_approved', (_) => _loadReports());
          RealtimeService().on('report_change_requested', (_) => _loadReports());
          RealtimeService().on('report_updated', (_) => _loadReports());
          RealtimeService().on('report_deleted', (_) => _loadReports());
        }
      } catch (_) {}
    });
  }

  Future<void> _loadReportDocuments() async {
    try {
      setState(() => _isLoading = true);
      final response = await _documentService.getDocuments(
        fileType: 'pdf', // Focus on PDF reports
        search: 'report', // Search for report-related documents
      );
      
      if (response.isSuccess) {
        setState(() {
          _reportDocuments = (response.data!['documents'] as List).cast<RepositoryFile>();
        });
      }
    } catch (e) {
      // Handle error silently for now
      // Error loading report documents: $e
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadReports() async {
    try {
      setState(() => _isLoading = true);
      // Always fetch all reports to ensure we can resolve document names
      final response = await _reportService.getSignOffReports(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        projectId: _selectedProjectId,
        sprintId: _selectedSprintId,
        deliverableId: _selectedDeliverableId,
        from: _fromDate?.toIso8601String(),
        to: _toDate?.toIso8601String(),
      );

      debugPrint('📋 Load reports response: success=${response.isSuccess}, data type=${response.data?.runtimeType}');
      
      if (response.isSuccess && response.data != null) {
        // ApiClient already extracts the 'data' field, so response.data is the list directly
        // But check if it's a List or a Map with a 'data' key
        final reportsData = response.data is List 
            ? response.data as List
            : (response.data!['data'] as List? ?? []);
        
        debugPrint('📋 Parsed ${reportsData.length} reports');
        setState(() {
          _reports = reportsData.map((json) {
            final dynamic contentRaw = json['content'];
            final Map<String, dynamic>? parsedContent = contentRaw is Map
                ? Map<String, dynamic>.from(contentRaw)
                : (contentRaw is String
                    ? (() {
                        try {
                          final decoded = jsonDecode(contentRaw);
                          return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
                        } catch (_) {
                          return null;
                        }
                      })()
                    : null);
            final content = (parsedContent != null && parsedContent.isNotEmpty)
                ? parsedContent
                : {
                    'reportTitle': json['reportTitle'] ?? json['report_title'],
                    'reportContent': json['reportContent'] ?? json['report_content'],
                    'sprintIds': json['sprintIds'] ?? json['sprint_ids'],
                    'sprintPerformanceData': json['sprintPerformanceData'] ?? json['sprint_performance_data'],
                    'knownLimitations': json['knownLimitations'] ?? json['known_limitations'],
                    'nextSteps': json['nextSteps'] ?? json['next_steps'],
                  };
            final reviews = json['reviews'] as List? ?? [];
            final latestReview = reviews.isNotEmpty ? reviews[0] : null;
            final preparedByName = (json['preparedByName'] ??
                    json['prepared_by_name'] ??
                    content['preparedByName'] ??
                    content['prepared_by_name'] ??
                    json['createdByName'] ??
                    json['created_by_name'])
                ?.toString();
            final merged = Map<String, dynamic>.from(json as Map);
            merged['content'] = content;
            final parsed = SignOffReport.fromJson(merged);
            return parsed.copyWith(
              preparedByName: preparedByName,
              reviewedAt: latestReview != null && latestReview['approved_at'] != null
                  ? _parseDateTime(latestReview['approved_at'])
                  : parsed.reviewedAt,
              reviewedBy: latestReview?['reviewerName']?.toString() ?? parsed.reviewedBy,
              approvedAt: latestReview != null &&
                      latestReview['approved_at'] != null &&
                      latestReview['reviewStatus'] == 'approved'
                  ? _parseDateTime(latestReview['approved_at'])
                  : parsed.approvedAt,
              approvedBy: latestReview != null && latestReview['reviewStatus'] == 'approved'
                  ? latestReview['reviewerName']?.toString()
                  : parsed.approvedBy,
              changeRequestDetails: latestReview != null && latestReview['reviewStatus'] == 'change_requested'
                  ? latestReview['feedback']?.toString()
                  : parsed.changeRequestDetails,
            );
          }).toList();
        });
      } else {
        final alt = await BackendApiService().getSignOffReports(
          search: _searchQuery.isNotEmpty ? _searchQuery : null,
        );
        if (alt.isSuccess && alt.data != null) {
          final reportsData = alt.data is List 
              ? alt.data as List
              : (alt.data!['data'] as List? ?? []);
          setState(() {
            _reports = reportsData.map((json) {
              final dynamic contentRaw = json['content'];
              final Map<String, dynamic>? parsedContent = contentRaw is Map
                  ? Map<String, dynamic>.from(contentRaw)
                  : (contentRaw is String
                      ? (() {
                          try {
                            final decoded = jsonDecode(contentRaw);
                            return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
                          } catch (_) {
                            return null;
                          }
                        })()
                      : null);
              final content = (parsedContent != null && parsedContent.isNotEmpty)
                  ? parsedContent
                  : {
                      'reportTitle': json['reportTitle'] ?? json['report_title'],
                      'reportContent': json['reportContent'] ?? json['report_content'],
                      'sprintIds': json['sprintIds'] ?? json['sprint_ids'],
                      'sprintPerformanceData': json['sprintPerformanceData'] ?? json['sprint_performance_data'],
                      'knownLimitations': json['knownLimitations'] ?? json['known_limitations'],
                      'nextSteps': json['nextSteps'] ?? json['next_steps'],
                    };
              final reviews = json['reviews'] as List? ?? [];
              final latestReview = reviews.isNotEmpty ? reviews[0] : null;
              final preparedByName = (json['preparedByName'] ??
                      json['prepared_by_name'] ??
                      content['preparedByName'] ??
                      content['prepared_by_name'] ??
                      json['createdByName'] ??
                      json['created_by_name'])
                  ?.toString();
              final merged = Map<String, dynamic>.from(json as Map);
              merged['content'] = content;
              final parsed = SignOffReport.fromJson(merged);
              return parsed.copyWith(
                preparedByName: preparedByName,
                reviewedAt: latestReview != null && latestReview['approved_at'] != null
                    ? _parseDateTime(latestReview['approved_at'])
                    : parsed.reviewedAt,
                reviewedBy: latestReview?['reviewerName']?.toString() ?? parsed.reviewedBy,
                approvedAt: latestReview != null &&
                        latestReview['approved_at'] != null &&
                        latestReview['reviewStatus'] == 'approved'
                    ? _parseDateTime(latestReview['approved_at'])
                    : parsed.approvedAt,
                approvedBy: latestReview != null && latestReview['reviewStatus'] == 'approved'
                    ? latestReview['reviewerName']?.toString()
                    : parsed.approvedBy,
                changeRequestDetails: latestReview != null && latestReview['reviewStatus'] == 'change_requested'
                    ? latestReview['feedback']?.toString()
                    : parsed.changeRequestDetails,
              );
            }).toList();
          });
        } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load reports: ${response.error ?? alt.error ?? "Unknown error"}'),
              backgroundColor: FlownetColors.crimsonRed,
            ),
          );
        }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading reports: $e'),
            backgroundColor: FlownetColors.crimsonRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFilterOptions() async {
    try {
      final api = BackendApiService();
      
      // Fetch filter data in parallel
      final results = await Future.wait([
        api.getProjects(),
        api.getSprints(), // Assuming this exists or similar
        api.getDeliverables(limit: 100), // Fetch top 100 deliverables for filter
      ]);

      if (mounted) {
        setState(() {
          // Process Projects
          if (results[0].isSuccess && results[0].data != null) {
            final data = results[0].data;
            final list = (data is Map ? (data['data'] ?? data['projects']) : data) as List? ?? [];
            _projects.clear();
            _projects.addAll(list.map((e) => Map<String, dynamic>.from(e)));
          }

          // Process Sprints
          if (results[1].isSuccess && results[1].data != null) {
            final data = results[1].data;
            final list = (data is Map ? (data['data'] ?? data['sprints']) : data) as List? ?? [];
            _sprints.clear();
            _sprints.addAll(list.map((e) => Map<String, dynamic>.from(e)));
          }

          // Process Deliverables
          if (results[2].isSuccess && results[2].data != null) {
            final data = results[2].data;
            final list = (data is Map ? (data['data'] ?? data['deliverables']) : data) as List? ?? [];
            _deliverables.clear();
            _deliverables.addAll(list.map((e) => Map<String, dynamic>.from(e)));
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading filter options: $e');
    }
  }

  DateTime? _parseDateTime(dynamic dateValue) {
    if (dateValue == null) return null;
    try {
      if (dateValue is String) {
        return DateTime.parse(dateValue).toLocal();
      } else if (dateValue is DateTime) {
        return dateValue.toLocal();
      }
    } catch (e) {
      debugPrint('Error parsing date: $dateValue - $e');
    }
    return null;
  }

  List<SignOffReport> get _filteredReports {
    var filtered = _reports;

    // Apply status filter
    if (_selectedFilter != 'all') {
      final status = ReportStatus.values.firstWhere(
        (e) => e.name == _selectedFilter,
        orElse: () => ReportStatus.draft,
      );
      filtered = filtered.where((report) => report.status == status).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((report) =>
          report.displayTitle.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          report.createdBy.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          report.deliverableId.toLowerCase().contains(_searchQuery.toLowerCase()),
      ).toList();
    }

    return filtered;
  }

  void _showReportDetails(SignOffReport report) {
    context.go('/report-view/${report.id}');
  }

  void _showClientFeedbackDialog(SignOffReport report) {
    final feedbackController = TextEditingController();
    final signatureKey = GlobalKey<SignatureCaptureWidgetState>();
    bool requestChanges = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: FlownetColors.graphiteGray,
          title: const Row(
            children: [
              Icon(Icons.comment, color: _reportsAccentBlue),
              SizedBox(width: 8),
              Text(
                'Add Client Feedback',
                style: TextStyle(color: FlownetColors.pureWhite),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report: ${report.displayTitle}',
                  style: const TextStyle(
                    color: FlownetColors.coolGray,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text(
                    'Request changes to this report',
                    style: TextStyle(color: FlownetColors.pureWhite),
                  ),
                  value: requestChanges,
                  onChanged: (value) {
                    setState(() => requestChanges = value ?? false);
                  },
                  activeColor: _reportsAccentBlue,
                  checkColor: FlownetColors.pureWhite,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: feedbackController,
                  maxLines: 8,
                  style: const TextStyle(color: FlownetColors.pureWhite),
                  decoration: InputDecoration(
                    labelText: requestChanges ? 'Change Request Details' : 'Feedback/Comments (Optional)',
                    labelStyle: const TextStyle(color: FlownetColors.coolGray),
                    hintText: requestChanges 
                        ? 'Describe what changes are needed...'
                        : 'Share your feedback or suggestions...',
                    helperText: requestChanges
                        ? 'Required when requesting changes'
                        : null,
                    hintStyle: const TextStyle(color: FlownetColors.coolGray),
                    border: const OutlineInputBorder(
                      borderSide: BorderSide(color: FlownetColors.slate),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: FlownetColors.slate),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: _reportsAccentBlue),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SignatureCaptureWidget(
                  key: signatureKey,
                  allowSignatureReuse: true,
                  showAuditInfo: true,
                  reportId: report.id,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: FlownetColors.coolGray)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final nav = Navigator.of(context);
                if (requestChanges && feedbackController.text.trim().isEmpty) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Change request details are required'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                final sig = await signatureKey.currentState?.getSignature();
                if (sig == null || sig.trim().isEmpty) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Digital signature is required'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                if (!context.mounted) return;
                nav.pop();
                await _submitClientFeedback(
                  report.id,
                  feedbackController.text.trim().isNotEmpty ? feedbackController.text.trim() : null,
                  requestChanges,
                  sig,
                );
              },
              icon: Icon(requestChanges ? Icons.change_circle : Icons.send),
              label: Text(requestChanges ? 'Request Changes' : 'Submit Feedback'),
              style: ElevatedButton.styleFrom(
                backgroundColor: requestChanges 
                    ? FlownetColors.amberOrange 
                    : _reportsAccentBlue,
                foregroundColor: FlownetColors.pureWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitClientFeedback(String reportId, String? feedback, bool requestChanges, String digitalSignature) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 16),
                Text('Submitting feedback...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      final response = requestChanges
          ? await _reportService.requestChanges(reportId, changeRequestDetails: feedback, digitalSignature: digitalSignature)
          : await _reportService.approveReport(reportId, comment: feedback, digitalSignature: digitalSignature);

      // Hide loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (response.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    requestChanges 
                        ? 'Changes requested successfully!' 
                        : 'Feedback submitted successfully!',
                  ),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
          _loadReports(); // Reload to show updated status
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${response.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting feedback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }




  Future<void> _previewDocument(RepositoryFile document) async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: DocumentPreviewWidget(
          document: document,
          documentService: _documentService,
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: FlownetColors.emeraldGreen,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: FlownetColors.crimsonRed,
      ),
    );
  }

  Widget _buildAdvancedFiltersPanel() {
    return Card(
      color: FlownetColors.surfaceLight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Advanced Filters',
                  style: TextStyle(
                    color: FlownetColors.pureWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                TextButton.icon(
                  onPressed: _clearAdvancedFilters,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear All'),
                  style: TextButton.styleFrom(
                    foregroundColor: FlownetColors.coolGray,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                // Project Filter
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedProjectId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Project',
                      labelStyle: TextStyle(color: FlownetColors.coolGray),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    dropdownColor: FlownetColors.surfaceLight,
                    style: const TextStyle(color: FlownetColors.pureWhite),
                    selectedItemBuilder: (context) {
                      return [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('All Projects', overflow: TextOverflow.ellipsis, maxLines: 1),
                        ),
                        ..._projects.map((p) {
                          final label = p['name']?.toString() ?? 'Unknown';
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
                          );
                        }),
                      ];
                    },
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Projects')),
                      ..._projects.map((p) => DropdownMenuItem(
                        value: p['id']?.toString(),
                        child: Text(p['name']?.toString() ?? 'Unknown', overflow: TextOverflow.ellipsis, maxLines: 1),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedProjectId = value);
                      _loadReports();
                    },
                  ),
                ),
                // Sprint Filter
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSprintId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Sprint',
                      labelStyle: TextStyle(color: FlownetColors.coolGray),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    dropdownColor: FlownetColors.surfaceLight,
                    style: const TextStyle(color: FlownetColors.pureWhite),
                    selectedItemBuilder: (context) {
                      return [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('All Sprints', overflow: TextOverflow.ellipsis, maxLines: 1),
                        ),
                        ..._sprints.map((s) {
                          final label = s['name']?.toString() ?? 'Unknown';
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
                          );
                        }),
                      ];
                    },
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Sprints')),
                      ..._sprints.map((s) => DropdownMenuItem(
                        value: s['id']?.toString(),
                        child: Text(s['name']?.toString() ?? 'Unknown', overflow: TextOverflow.ellipsis, maxLines: 1),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedSprintId = value);
                      _loadReports();
                    },
                  ),
                ),
                // Deliverable Filter
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedDeliverableId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Deliverable',
                      labelStyle: TextStyle(color: FlownetColors.coolGray),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    dropdownColor: FlownetColors.surfaceLight,
                    style: const TextStyle(color: FlownetColors.pureWhite),
                    selectedItemBuilder: (context) {
                      return [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('All Deliverables', overflow: TextOverflow.ellipsis, maxLines: 1),
                        ),
                        ..._deliverables.map((d) {
                          final label = d['title']?.toString() ?? d['name']?.toString() ?? 'Unknown';
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
                          );
                        }),
                      ];
                    },
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Deliverables')),
                      ..._deliverables.map((d) => DropdownMenuItem(
                        value: d['id']?.toString(),
                        child: Text(
                          d['title']?.toString() ?? d['name']?.toString() ?? 'Unknown',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedDeliverableId = value);
                      _loadReports();
                    },
                  ),
                ),
                // Date Range - From
                SizedBox(
                  width: 160,
                  child: InkWell(
                    onTap: () => _selectDate(isFrom: true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'From Date',
                        labelStyle: TextStyle(color: FlownetColors.coolGray),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(
                        _fromDate != null ? _formatDate(_fromDate!) : 'Any',
                        style: const TextStyle(color: FlownetColors.pureWhite),
                      ),
                    ),
                  ),
                ),
                // Date Range - To
                SizedBox(
                  width: 160,
                  child: InkWell(
                    onTap: () => _selectDate(isFrom: false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'To Date',
                        labelStyle: TextStyle(color: FlownetColors.coolGray),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(
                        _toDate != null ? _formatDate(_toDate!) : 'Any',
                        style: const TextStyle(color: FlownetColors.pureWhite),
                      ),
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

  void _clearAdvancedFilters() {
    setState(() {
      _selectedProjectId = null;
      _selectedSprintId = null;
      _selectedDeliverableId = null;
      _fromDate = null;
      _toDate = null;
    });
    _loadReports();
  }

  Future<void> _selectDate({required bool isFrom}) async {
    final initialDate = isFrom ? (_fromDate ?? DateTime.now()) : (_toDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _ReportRepositoryScreenState._reportsAccentBlue,
              surface: FlownetColors.surfaceLight,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
      _loadReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppScaffold(
        useBackgroundImage: true,
        useGlassContainer: false,
        centered: false,
        scrollable: false,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return AppScaffold(
      useBackgroundImage: true,
      centered: false,
      scrollable: false,
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: Colors.transparent,
        foregroundColor: FlownetColors.pureWhite,
        centerTitle: false,
        elevation: 0,
        actions: [
          if (AuthService().currentUser?.isDeliveryLead ?? false)
            TextButton.icon(
              onPressed: _startSprintBasedReportCreation,
              icon: const Icon(Icons.add),
              label: const Text('Create Report'),
              style: TextButton.styleFrom(
                foregroundColor: FlownetColors.crimsonRed,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search reports...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                              _loadReports();
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    _loadReports();
                  },
                ),
                const SizedBox(height: 16),
                
                // Filter Chips Row with Advanced Filters Toggle
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('all', 'All'),
                            const SizedBox(width: 8),
                            _buildFilterChip('draft', 'Draft'),
                            const SizedBox(width: 8),
                            _buildFilterChip('submitted', 'Submitted'),
                            const SizedBox(width: 8),
                            _buildFilterChip('underReview', 'Under Review'),
                            const SizedBox(width: 8),
                            _buildFilterChip('approved', 'Approved'),
                            const SizedBox(width: 8),
                            _buildFilterChip('changeRequested', 'Change Requested'),
                            const SizedBox(width: 8),
                            _buildFilterChip('rejected', 'Rejected'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        _showAdvancedFilters ? Icons.filter_alt_off : Icons.filter_alt,
                        color: _showAdvancedFilters ? _reportsAccentBlue : FlownetColors.coolGray,
                      ),
                      tooltip: 'Advanced Filters',
                      onPressed: () {
                        setState(() {
                          _showAdvancedFilters = !_showAdvancedFilters;
                        });
                      },
                    ),
                  ],
                ),

                // Advanced Filters Panel
                if (_showAdvancedFilters) ...[
                  const SizedBox(height: 16),
                  _buildAdvancedFiltersPanel(),
                ],
              ],
            ),
          ),

          // Reports and Documents Tabs
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    labelColor: _reportsAccentBlue,
                    unselectedLabelColor: FlownetColors.coolGray,
                    indicatorColor: _reportsAccentBlue,
                    tabs: [
                      Tab(text: 'Reports', icon: Icon(Icons.assignment)),
                      Tab(text: 'Documents', icon: Icon(Icons.folder)),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Reports Tab
                        _filteredReports.isEmpty
                            ? const Center(
                                child: Text(
                                  'No reports found',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _filteredReports.length,
                                itemBuilder: (context, index) {
                                  final report = _filteredReports[index];
                                  return _buildReportCard(report);
                                },
                              ),
                        // Documents Tab
                        _reportDocuments.isEmpty
                            ? const Center(
                                child: Text(
                                  'No report documents found',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _reportDocuments.length,
                                itemBuilder: (context, index) {
                                  final document = _reportDocuments[index];
                                  return _buildDocumentCard(document);
                                },
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDisplayName(RepositoryFile document) {
    // Check if the name matches a report ID pattern (e.g. "report_123.pdf" or "123.pdf")
    final name = document.name;
    String? reportId;
    
    // Try to extract ID from various patterns
    // 1. Exact match: ID.pdf
    var match = RegExp(r'^([a-zA-Z0-9-]+)\.pdf$').firstMatch(name);
    
    // 2. Prefix match: report_ID.pdf or Title_ID.pdf
    match ??= RegExp(r'[._-]([a-zA-Z0-9-]+)\.pdf$').firstMatch(name);

    if (match != null) {
      reportId = match.group(1);
    }
    
    if (reportId != null) {
      try {
        final report = _reports.firstWhere((r) => r.id == reportId);
        return '${report.displayTitle}.pdf';
      } catch (_) {
        // Report not found
      }
    }
    
    return name;
  }

  Widget _buildDocumentCard(RepositoryFile document) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: FlownetColors.graphiteGray.withValues(alpha: 0.6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getFileTypeColor(document.fileType),
          child: Text(
            document.fileType.toUpperCase().substring(0, 1),
            style: const TextStyle(
              color: FlownetColors.pureWhite,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          _getDisplayName(document),
          style: const TextStyle(
            color: FlownetColors.pureWhite,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Uploaded by: ${document.uploaderName ?? document.uploader}',
              style: const TextStyle(color: FlownetColors.coolGray),
            ),
            Text(
              'Size: ${_formatFileSize(document.sizeInMB.toString())} • ${_formatDate(document.uploadDate)}',
              style: const TextStyle(color: FlownetColors.coolGray),
            ),
            if (document.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  document.description,
                  style: const TextStyle(
                    color: FlownetColors.coolGray,
                    fontSize: 12,
                  ),
                ),
              ),
            if (document.tags != null && document.tags!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  children: document.tags!.split(',').map((tag) => Chip(
                    label: Text(tag.trim(), style: const TextStyle(fontSize: 10)),
                    backgroundColor: _reportsAccentBlue.withValues(alpha: 0.2),
                    labelStyle: const TextStyle(color: _reportsAccentBlue),
                  ),).toList(),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility, color: _reportsAccentBlue),
              onPressed: () => _previewDocument(document),
              tooltip: 'Preview',
            ),
            IconButton(
              icon: const Icon(Icons.download, color: _reportsAccentBlue),
              onPressed: () => _downloadDocument(document),
              tooltip: 'Download',
            ),
            // Delete button - only for system admins, delivery leads, and document uploader
            if (_canDeleteDocument(document))
              IconButton(
                icon: const Icon(Icons.delete, color: FlownetColors.crimsonRed),
                onPressed: () => _confirmDeleteDocument(document),
                tooltip: 'Delete',
              ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Color _getFileTypeColor(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return FlownetColors.crimsonRed;
      case 'doc':
      case 'docx':
        return FlownetColors.amberOrange;
      case 'xls':
      case 'xlsx':
        return FlownetColors.emeraldGreen;
      case 'txt':
        return FlownetColors.slate;
      default:
        return _reportsAccentBlue;
    }
  }

  String _formatFileSize(String sizeInMB) {
    final size = double.tryParse(sizeInMB) ?? 0;
    if (size < 1) {
      return '${(size * 1024).toStringAsFixed(0)} KB';
    }
    return '${size.toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    final tz = date.toUtc().add(const Duration(hours: 2));
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${two(tz.day)}/${two(tz.month)}/${tz.year} ${two(tz.hour)}:${two(tz.minute)}';
  }

  Future<void> _downloadDocument(RepositoryFile document) async {
    try {
      final response = await _documentService.downloadDocument(document.id);
      if (response.isSuccess) {
        _showSuccessSnackBar('Document downloaded successfully!');
      } else {
        _showErrorSnackBar('Download failed: ${response.error}');
      }
    } catch (e) {
      _showErrorSnackBar('Download error: $e');
    }
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
        _loadReports();
      },
      backgroundColor: FlownetColors.slate,
      selectedColor: _reportsAccentBlue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey,
      ),
    );
  }

  Future<void> _runReportAction({
    required String successMessage,
    required Future<dynamic> Function() action,
  }) async {
    try {
      final response = await action();
      if (!mounted) return;
      if (response.isSuccess) {
        _showSuccessSnackBar(successMessage);
        await _loadReports();
      } else {
        _showErrorSnackBar(response.error ?? 'Action failed');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Action failed: $e');
    }
  }

  Future<void> _handleReportMenuAction(SignOffReport report, String value) async {
    switch (value) {
      case 'seal':
        await _runReportAction(
          successMessage: 'Report sealed successfully',
          action: () => _reportService.sealReport(report.id),
        );
        return;
      case 'archive':
        await _runReportAction(
          successMessage: 'Report archived successfully',
          action: () => _reportService.archiveReport(report.id),
        );
        return;
      case 'remind':
        await _runReportAction(
          successMessage: 'Review reminder sent',
          action: () => _reportService.sendReminder(report.id),
        );
        return;
      case 'escalate':
        await _runReportAction(
          successMessage: 'Report escalated successfully',
          action: () => _reportService.escalateReport(report.id),
        );
        return;
      case 'delete':
        await _confirmDeleteReport(report);
        return;
    }
  }

  Widget _buildReportCard(SignOffReport report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: FlownetColors.graphiteGray.withValues(alpha: 0.6),
      child: InkWell(
        onTap: () => _showReportDetails(report),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            report.displayTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (report.status == ReportStatus.approved) ...[
                          const SizedBox(width: 8),
                          const Tooltip(
                            message: 'Sealed (Approved)',
                            child: Icon(Icons.lock, color: FlownetColors.emeraldGreen, size: 16),
                          ),
                        ],
                        if (report.isArchived) ...[
                          const SizedBox(width: 8),
                          const Tooltip(
                            message: 'Archived',
                            child: Icon(Icons.archive, color: FlownetColors.coolGray, size: 16),
                          ),
                        ],
                        if (report.status == ReportStatus.submitted) ...[
                          const SizedBox(width: 8),
                          const Tooltip(
                            message: 'Submitted (Editable)',
                            child: Icon(Icons.edit, color: Colors.orange, size: 16),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: report.statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: report.statusColor),
                    ),
                    child: Text(
                      report.statusDisplayName,
                      style: TextStyle(
                        color: report.statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (report.currentVersion > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: FlownetColors.electricBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: FlownetColors.electricBlue),
                      ),
                      child: Text(
                        'v${report.currentVersion}',
                        style: const TextStyle(
                          color: FlownetColors.electricBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  PopupMenuButton<String>(
                    itemBuilder: (context) => [
                      if ((report.status == ReportStatus.submitted ||
                              report.status == ReportStatus.underReview) &&
                          !report.isArchived)
                        const PopupMenuItem(
                          value: 'remind',
                          child: Text('Send Reminder'),
                        ),
                      if ((report.status == ReportStatus.submitted ||
                              report.status == ReportStatus.underReview) &&
                          !report.isArchived)
                        const PopupMenuItem(
                          value: 'escalate',
                          child: Text('Escalate'),
                        ),
                      if (report.status == ReportStatus.approved &&
                          report.sealedAt == null &&
                          !report.isArchived)
                        const PopupMenuItem(
                          value: 'seal',
                          child: Text('Seal'),
                        ),
                      if ((report.status == ReportStatus.approved ||
                              report.status == ReportStatus.rejected) &&
                          !report.isArchived)
                        const PopupMenuItem(
                          value: 'archive',
                          child: Text('Archive'),
                        ),
                      if (!report.isArchived)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                    ],
                    onSelected: (value) async {
                      await _handleReportMenuAction(report, value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Details
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      Icons.person,
                      (report.preparedByName?.trim().isNotEmpty ?? false)
                          ? report.preparedByName!.trim()
                          : (report.createdBy.isNotEmpty ? report.createdBy : '—'),
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      Icons.calendar_today,
                      _formatDate(report.createdAt),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Sprint IDs
              if (report.sprintIds.isNotEmpty)
                _buildInfoItem(
                  Icons.timeline,
                  'Sprints: ${report.sprintIds.join(', ')}',
                ),
              if (report.isArchived || report.sealedAt != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (report.sealedAt != null)
                      _buildMetadataChip(
                        label: 'Sealed ${_formatDate(report.sealedAt!)}',
                        color: FlownetColors.emeraldGreen,
                      ),
                    if (report.isArchived && report.archivedAt != null)
                      _buildMetadataChip(
                        label: 'Archived ${_formatDate(report.archivedAt!)}',
                        color: FlownetColors.coolGray,
                      ),
                  ],
                ),
              ],

              // Digital Signature indicator
              if (report.digitalSignature != null) ...[
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(
                      Icons.verified,
                      color: Colors.green,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Digitally Signed',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],

              // Quick Action Buttons
              const SizedBox(height: 12),
              const Divider(color: FlownetColors.slate, height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Edit button for draft, submitted, and change_requested reports
                  if (report.status == ReportStatus.draft || 
                      report.status == ReportStatus.submitted ||
                      report.status == ReportStatus.changeRequested) ...[
                    TextButton.icon(
                      onPressed: report.isArchived
                          ? null
                          : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReportEditorScreen(reportId: report.id),
                          ),
                        ).then((_) => _loadReports());
                      },
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      style: TextButton.styleFrom(
                        foregroundColor: _reportsAccentBlue,
                      ),
                    ),
                  ],
                  // Review button for submitted reports (CLIENT REVIEWERS ONLY)
                  if ((report.status == ReportStatus.submitted || 
                      report.status == ReportStatus.underReview) &&
                      AuthService().currentUser?.role == UserRole.clientReviewer) ...[
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ClientReviewWorkflowScreen(reportId: report.id),
                          ),
                        ).then((_) => _loadReports());
                      },
                      icon: const Icon(Icons.rate_review, size: 16),
                      label: const Text('Review'),
                      style: TextButton.styleFrom(
                        foregroundColor: FlownetColors.amberOrange,
                      ),
                    ),
                  ],
                  // Feedback button for submitted/reviewed/approved reports
                  if ((report.status == ReportStatus.submitted || 
                      report.status == ReportStatus.underReview ||
                      report.status == ReportStatus.approved) &&
                      AuthService().currentUser?.role == UserRole.clientReviewer) ...[
                    TextButton.icon(
                      onPressed: () => _showClientFeedbackDialog(report),
                      icon: const Icon(Icons.comment, size: 16),
                      label: const Text('Feedback'),
                      style: TextButton.styleFrom(
                        foregroundColor: _reportsAccentBlue,
                      ),
                    ),
                  ],
                  // Export button (for client reviewers and delivery leads)
                  if (AuthService().currentUser?.role == UserRole.clientReviewer || 
                      AuthService().currentUser?.role == UserRole.deliveryLead) ...[
                    TextButton.icon(
                      onPressed: () => _exportReport(report),
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Export'),
                      style: TextButton.styleFrom(
                        foregroundColor: _reportsAccentBlue,
                      ),
                    ),
                  ],
                  // View details button (always available)
                  TextButton.icon(
                    onPressed: () => _showReportDetails(report),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('Details'),
                    style: TextButton.styleFrom(
                      foregroundColor: FlownetColors.coolGray,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteReport(SignOffReport report) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FlownetColors.graphiteGray,
        title: const Text('Delete Report', style: TextStyle(color: FlownetColors.pureWhite)),
        content: Text(
          'Are you sure you want to delete "${report.displayTitle}"?',
          style: const TextStyle(color: FlownetColors.coolGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: FlownetColors.coolGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: FlownetColors.crimsonRed),
            child: const Text('Delete', style: TextStyle(color: FlownetColors.pureWhite)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final api = BackendApiService();
        final response = await api.deleteSignOffReport(report.id);
        if (response.isSuccess) {
          setState(() {
            _reports.removeWhere((r) => r.id == report.id);
          });
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Report deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadReports();
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Failed to delete report: ${response.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error deleting report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  bool _canDeleteDocument(RepositoryFile document) {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) return false;
    
    // System admins can delete any document
    if (currentUser.role == UserRole.systemAdmin) return true;
    
    // Delivery leads can delete any document
    if (currentUser.role == UserRole.deliveryLead) return true;
    
    // Document uploader can delete their own documents
    // Check by uploader ID or uploader email/name match
    if (document.uploader == currentUser.id) return true;
    if (document.uploaderName == currentUser.email) return true;
    
    return false;
  }

  Future<void> _confirmDeleteDocument(RepositoryFile document) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FlownetColors.graphiteGray,
        title: const Text('Delete Document', style: TextStyle(color: FlownetColors.pureWhite)),
        content: Text(
          'Are you sure you want to delete "${_getDisplayName(document)}"?\n\nThis action cannot be undone.',
          style: const TextStyle(color: FlownetColors.coolGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: FlownetColors.coolGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: FlownetColors.crimsonRed),
            child: const Text('Delete', style: TextStyle(color: FlownetColors.pureWhite)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final response = await _documentService.deleteDocument(document.id);
        if (response.isSuccess) {
          setState(() {
            _reportDocuments.removeWhere((doc) => doc.id == document.id);
          });
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Document deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadReportDocuments(); // Refresh the document list
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Failed to delete document: ${response.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error deleting document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportReport(SignOffReport report) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Show export options
      final format = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: FlownetColors.graphiteGray,
          title: const Text(
            'Export Report',
            style: TextStyle(color: FlownetColors.pureWhite),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: _reportsAccentBlue),
                title: const Text('PDF', style: TextStyle(color: FlownetColors.pureWhite)),
                onTap: () => Navigator.pop(context, 'pdf'),
              ),
              ListTile(
                leading: const Icon(Icons.print, color: _reportsAccentBlue),
                title: const Text('Print', style: TextStyle(color: FlownetColors.pureWhite)),
                onTap: () => Navigator.pop(context, 'print'),
              ),
            ],
          ),
        ),
      );

      if (format == null) return;

      if (format == 'pdf') {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Preparing your PDF in the background…'),
            backgroundColor: Colors.blue,
          ),
        );
        Future<void>(() async {
          try {
            await _exportService.exportReportAsPDFFromServer(report);
            if (!mounted) return;
            messenger.showSnackBar(
              const SnackBar(
                content: Text('PDF download started'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            if (!mounted) return;
            messenger.showSnackBar(
              SnackBar(
                content: Text('Error exporting report: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      } else if (format == 'print') {
        await _exportService.printReport(report);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error exporting report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
