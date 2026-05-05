import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../models/deliverable.dart';
import '../models/sign_off_report.dart';
import '../models/user_role.dart';
import '../services/backend_api_service.dart';
import '../services/auth_service.dart';
import '../services/sign_off_report_service.dart';
import '../services/user_data_service.dart';
import '../theme/flownet_theme.dart';
import '../widgets/flownet_logo.dart';
import '../widgets/sprint_performance_chart.dart';
import '../widgets/audit_history_widget.dart';
import 'client_review_workflow_screen.dart';

class ReportViewScreen extends ConsumerStatefulWidget {
  final String reportId;
  final bool showPostSubmitBanner;
  
  const ReportViewScreen({
    super.key,
    required this.reportId,
    this.showPostSubmitBanner = false,
  });

  @override
  ConsumerState<ReportViewScreen> createState() => _ReportViewScreenState();
}

class _ReportViewScreenState extends ConsumerState<ReportViewScreen> {
  SignOffReport? _report;
  Deliverable? _deliverable;
  bool _isLoading = true;
  final SignOffReportService _reportService = SignOffReportService(AuthService());
  final UserDataService _userDataService = UserDataService();

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<Deliverable?> _enrichDeliverableWithSubmittedByName({
    required Deliverable? deliverable,
    required SignOffReport report,
  }) async {
    if (deliverable == null) return null;
    if (deliverable.submittedByName != null && deliverable.submittedByName!.trim().isNotEmpty) {
      return deliverable;
    }

    final submittedById = (deliverable.submittedBy ?? report.submittedBy ?? '').toString();
    if (submittedById.trim().isEmpty) return deliverable;

    final user = await _userDataService.getUserById(submittedById);
    final name = user?.name.trim() ?? '';
    if (name.isEmpty) return deliverable;

    return deliverable.copyWith(submittedByName: name);
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    try {
      final api = BackendApiService();
      final reportResp = await api.getSignOffReport(widget.reportId);
      
      if (!mounted) return;
      
      if (reportResp.isSuccess && reportResp.data != null) {
        final reportJson = reportResp.data is Map ? (reportResp.data!['data'] ?? reportResp.data!['report'] ?? reportResp.data!) : reportResp.data;
        final loadedReport = SignOffReport.fromJson(reportJson);
        
        Deliverable? loadedDeliverable;
        if (loadedReport.deliverableId.isNotEmpty) {
          final delivResp = await api.getDeliverable(loadedReport.deliverableId);
          if (delivResp.isSuccess && delivResp.data != null) {
            final dJson = delivResp.data is Map ? (delivResp.data!['data'] ?? delivResp.data!['deliverable'] ?? delivResp.data!) : delivResp.data;
            loadedDeliverable = Deliverable.fromJson(dJson);
          }
        }

        loadedDeliverable = await _enrichDeliverableWithSubmittedByName(
          deliverable: loadedDeliverable,
          report: loadedReport,
        );
        
        setState(() {
          _report = loadedReport;
          _deliverable = loadedDeliverable;
          _isLoading = false;
        });
      } else {
        _handleError('Failed to load report data');
      }
    } catch (e) {
      _handleError('Error loading report: $e');
    }
  }

  void _handleError(String message) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _navigateToEdit() {
    if (_report == null) return;
    final deliverableId = _report!.deliverableId;
    if (deliverableId.isEmpty) return;
    context.go('/report-editor/$deliverableId?reportId=${Uri.encodeComponent(_report!.id)}');
  }

  void _showAuditHistory() {
    if (_report == null) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: FlownetColors.graphiteGray,
        child: Container(
          width: 600,
          height: 500,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Audit History',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: FlownetColors.pureWhite,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: FlownetColors.pureWhite),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: FlownetColors.slate),
              Expanded(
                child: AuditHistoryWidget(
                  reportId: _report!.id,
                  reportService: _reportService,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRole(String? raw) {
    final r = (raw ?? '').trim();
    if (r.isEmpty) return '';
    final norm = r.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    for (final role in UserRole.values) {
      final rn = role.name.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
      if (rn == norm) {
        return role.displayName;
      }
    }
    return r;
  }

  String _formatActor({required String? name, required String? role}) {
    final n = (name ?? '').trim();
    final r = _formatRole(role);
    if (n.isEmpty) return '';
    if (r.isEmpty) return n;
    return '$n ($r)';
  }

  Future<void> _submitClientFeedback(String feedback, bool requestChanges) async {
    if (_report == null) return;
    
    try {
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
          ? await _reportService.requestChanges(_report!.id, feedback)
          : await _reportService.approveReport(_report!.id, comment: feedback);

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
          _loadReportData(); // Reload to show updated status
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

  void _showClientFeedbackDialog() {
    if (_report == null) return;
    
    final feedbackController = TextEditingController();
    bool requestChanges = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: FlownetColors.graphiteGray,
          title: const Row(
            children: [
              Icon(Icons.comment, color: FlownetColors.electricBlue),
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
                  'Report: ${_report!.displayTitle}',
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
                  activeColor: FlownetColors.electricBlue,
                  checkColor: FlownetColors.pureWhite,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: feedbackController,
                  maxLines: 8,
                  style: const TextStyle(color: FlownetColors.pureWhite),
                  decoration: InputDecoration(
                    labelText: requestChanges ? 'Change Request Details *' : 'Feedback/Comments',
                    labelStyle: const TextStyle(color: FlownetColors.coolGray),
                    hintText: requestChanges 
                        ? 'Describe what changes are needed...'
                        : 'Share your feedback or suggestions...',
                    hintStyle: const TextStyle(color: FlownetColors.coolGray),
                    border: const OutlineInputBorder(
                      borderSide: BorderSide(color: FlownetColors.slate),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: FlownetColors.slate),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: FlownetColors.electricBlue),
                    ),
                  ),
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
                if (feedbackController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter your feedback'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                await _submitClientFeedback(
                  feedbackController.text.trim(),
                  requestChanges,
                );
              },
              icon: Icon(requestChanges ? Icons.change_circle : Icons.send),
              label: Text(requestChanges ? 'Request Changes' : 'Submit Feedback'),
              style: ElevatedButton.styleFrom(
                backgroundColor: requestChanges 
                    ? FlownetColors.amberOrange 
                    : FlownetColors.electricBlue,
                foregroundColor: FlownetColors.pureWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: FlownetColors.charcoalBlack,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_report == null) {
      return Scaffold(
        backgroundColor: FlownetColors.charcoalBlack,
        appBar: AppBar(
          title: const FlownetLogo(),
          backgroundColor: FlownetColors.charcoalBlack,
        ),
        body: const Center(
          child: Text('Report not found', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final userRole = AuthService().currentUser?.role;
    final isClientReviewer = userRole == UserRole.clientReviewer;
    final canEdit = !isClientReviewer && _report!.status != ReportStatus.approved;

    return Scaffold(
      backgroundColor: FlownetColors.charcoalBlack,
      appBar: AppBar(
        title: const FlownetLogo(),
        backgroundColor: FlownetColors.charcoalBlack,
        foregroundColor: FlownetColors.pureWhite,
        centerTitle: false,
        actions: [
          // Audit History Button
          IconButton(
            onPressed: _showAuditHistory,
            icon: const Icon(Icons.history, color: FlownetColors.electricBlue),
            tooltip: 'Audit History',
          ),
          
          // Review Button for Client Reviewers
          if ((_report!.status == ReportStatus.submitted || _report!.status == ReportStatus.underReview) &&
              isClientReviewer)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ClientReviewWorkflowScreen(reportId: _report!.id),
                    ),
                  ).then((_) => _loadReportData());
                },
                icon: const Icon(Icons.rate_review, size: 18),
                label: const Text('Review'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlownetColors.amberOrange,
                  foregroundColor: FlownetColors.pureWhite,
                ),
              ),
            ),

          // Feedback Button
          if ((_report!.status == ReportStatus.submitted || 
               _report!.status == ReportStatus.underReview) &&
               isClientReviewer)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TextButton.icon(
                onPressed: _showClientFeedbackDialog,
                icon: const Icon(Icons.comment, size: 18),
                label: const Text('Feedback'),
                style: TextButton.styleFrom(
                  foregroundColor: FlownetColors.electricBlue,
                ),
              ),
            ),

          if (canEdit)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TextButton.icon(
                onPressed: _navigateToEdit,
                icon: const Icon(Icons.edit, color: FlownetColors.electricBlue),
                label: const Text(
                  'Edit',
                  style: TextStyle(color: FlownetColors.electricBlue),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showPostSubmitBanner)
              Card(
                color: FlownetColors.graphiteGray,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.mark_email_read, color: FlownetColors.electricBlue),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'This is the submitted version of the report.',
                          style: TextStyle(color: FlownetColors.pureWhite, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (canEdit)
                        TextButton(
                          onPressed: _navigateToEdit,
                          child: const Text('Edit'),
                        ),
                    ],
                  ),
                ),
              ),
            if (widget.showPostSubmitBanner) const SizedBox(height: 16),
            // Header
            Text(
              'Report View',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: FlownetColors.pureWhite,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generated on ${formatDate(_report!.createdAt)}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: FlownetColors.coolGray,
              ),
            ),
            const SizedBox(height: 24),

            // Deliverable Status Card
            buildStatusCard(),
            const SizedBox(height: 24),

            // Change Request History (Action List)
            if (_report?.changeRequestHistory?.isNotEmpty == true || _report?.changeRequestDetails != null)
              _buildChangeRequestHistory(),

            // Report Content
            buildReportContent(),
          ],
        ),
      ),
    );
  }

  Widget buildStatusCard() {
    return Card(
      color: FlownetColors.graphiteGray,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.assignment,
                  color: FlownetColors.electricBlue,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Deliverable Status',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: FlownetColors.pureWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_deliverable == null) ...[
               buildStatusItem('Linked Deliverable ID', _report!.deliverableId),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: buildStatusItem('Title', _deliverable!.title),
                  ),
                  Expanded(
                    child: buildStatusItem('Status', _deliverable!.statusDisplayName),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: buildStatusItem('Due Date', formatDate(_deliverable!.dueDate)),
                  ),
                  Expanded(
                    child: buildStatusItem(
                      'Submitted By',
                      _formatActor(
                        name: _report!.submittedByName ?? _report!.submittedBy,
                        role: _report!.submittedByRole,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
              buildStatusItem(
                'Prepared By',
                _formatActor(
                  name: _report!.preparedByName ?? _report!.createdBy,
                  role: _report!.preparedByRole,
                ),
              ),
              const SizedBox(height: 8),
              buildStatusItem('Report Status', _report!.status.toString().split('.').last.toUpperCase()),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: buildStatusItem('Created', formatDate(_report!.createdAt))),
                  Expanded(child: buildStatusItem('Submitted', _report!.submittedAt != null ? formatDate(_report!.submittedAt!) : '')),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: buildStatusItem(
                      'Reviewed By',
                      _formatActor(
                        name: _report!.reviewedByName ?? _report!.reviewedBy,
                        role: _report!.reviewedByRole,
                      ),
                    ),
                  ),
                  Expanded(child: buildStatusItem('Reviewed', _report!.reviewedAt != null ? formatDate(_report!.reviewedAt!) : '')),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: buildStatusItem(
                      'Approved By',
                      _formatActor(
                        name: _report!.approvedByName ?? _report!.approvedBy,
                        role: _report!.approvedByRole,
                      ),
                    ),
                  ),
                  Expanded(child: buildStatusItem('Approved', _report!.approvedAt != null ? formatDate(_report!.approvedAt!) : '')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget buildStatusItem(String label, String value) {
    final trimmed = value.trim();
    final normalized = trimmed.isEmpty || trimmed.toLowerCase() == 'unknown' || trimmed.toLowerCase() == 'unknown user'
        ? '—'
        : value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
        Text(
          normalized,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildChangeRequestHistory() {
    if ((_report?.changeRequestHistory == null || _report!.changeRequestHistory!.isEmpty) && 
        _report?.changeRequestDetails == null) {
      return const SizedBox.shrink();
    }
    
    final history = _report?.changeRequestHistory ?? [];
    // If we have history in JSON format but not mapped, handle it
    final List<dynamic> historyList = history;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: Colors.orange),
              const SizedBox(width: 12),
              Text(
                'Change Request History (Action List)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_report?.changeRequestDetails != null) ...[
             _buildHistoryItem(
               details: _report!.changeRequestDetails!,
               date: _report!.reviewedAt,
               user: _report!.reviewedBy,
               isLatest: true,
             ),
             if (historyList.isNotEmpty) const Divider(color: Colors.orange, height: 24),
          ],
          ...historyList.map((item) {
             final i = item is Map ? item : {'details': item.toString()};
             return _buildHistoryItem(
               details: i['details'] ?? '',
               date: i['requestedAt'] != null ? DateTime.parse(i['requestedAt']) : null,
               user: i['requestedBy'],
               isLatest: false,
             );
          }),
        ],
      ),
    );
  }

  Widget _buildHistoryItem({
    required String details,
    DateTime? date,
    String? user,
    required bool isLatest,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isLatest ? 'Latest Request' : 'Previous Request',
              style: TextStyle(
                color: isLatest ? Colors.orange : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            if (date != null)
              Text(
                formatDate(date),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          details,
          style: const TextStyle(color: Colors.white),
        ),
        if (user != null) ...[
           const SizedBox(height: 4),
           Text(
             'Requested by: $user',
             style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
           ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget buildReportContent() {
    return Column(
      children: [
        Card(
          color: FlownetColors.graphiteGray,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.description,
                      color: FlownetColors.electricBlue,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _report!.displayTitle.isNotEmpty ? _report!.displayTitle : 'Sign-Off Report',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: FlownetColors.pureWhite,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _report!.reportContent,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildPerformanceVisuals(),
      ],
    );
  }

  Widget _buildPerformanceVisuals() {
    if (_report?.sprintPerformanceData == null || _report!.sprintPerformanceData!.isEmpty) {
      return const SizedBox.shrink();
    }

    try {
      final List<dynamic> rawData = jsonDecode(_report!.sprintPerformanceData!);
      final List<Map<String, dynamic>> sprints = rawData.map((e) => Map<String, dynamic>.from(e)).toList();

      if (sprints.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Metrics',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: FlownetColors.pureWhite,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Velocity Chart
          SizedBox(
            height: 300,
            child: SprintPerformanceChart(
              sprints: sprints,
              chartType: 'velocity',
            ),
          ),
          const SizedBox(height: 16),
          // Defects Trend
          SizedBox(
            height: 300,
            child: SprintPerformanceChart(
              sprints: sprints,
              chartType: 'defects',
            ),
          ),
          const SizedBox(height: 16),
          // Test Pass Rate
          SizedBox(
            height: 300,
            child: SprintPerformanceChart(
              sprints: sprints,
              chartType: 'test_pass_rate',
            ),
          ),
        ],
      );
    } catch (e) {
      debugPrint('Error parsing sprint performance data: $e');
      return const SizedBox.shrink();
    }
  }

  String formatDate(DateTime date) {
    final tz = date.toUtc().add(const Duration(hours: 2));
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${two(tz.day)}/${two(tz.month)}/${tz.year} ${two(tz.hour)}:${two(tz.minute)}';
  }
}
