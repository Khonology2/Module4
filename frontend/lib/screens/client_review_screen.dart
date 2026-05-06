import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../models/deliverable.dart';
import '../models/sign_off_report.dart';
import '../services/backend_api_service.dart';
import '../theme/flownet_theme.dart';
import '../widgets/flownet_logo.dart';
import '../widgets/signature_capture_widget.dart';
import '../widgets/sprint_performance_chart.dart';

class ClientReviewScreen extends ConsumerStatefulWidget {
  final String reportId;
  final SignOffReport? initialReport;
  final Deliverable? initialDeliverable;
  final String? reviewToken; // Token for token-based access (no auth required)

  const ClientReviewScreen({
    super.key,
    required this.reportId,
    this.initialReport,
    this.initialDeliverable,
    this.reviewToken,
  });

  @override
  ConsumerState<ClientReviewScreen> createState() => _ClientReviewScreenState();
}

class _ClientReviewScreenState extends ConsumerState<ClientReviewScreen> {
  final _commentController = TextEditingController();
  final _changeRequestController = TextEditingController();
  final GlobalKey<SignatureCaptureWidgetState> _signatureKey =
      GlobalKey<SignatureCaptureWidgetState>();
  String? _capturedSignature;

  SignOffReport? _report;
  Deliverable? _deliverable;
  bool _isSubmitting = false;
  String _selectedAction = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialReport != null) {
      _report = widget.initialReport;
      _deliverable = widget.initialDeliverable;
      final needsFullFetch = (_report?.reportContent.isEmpty ?? true) ||
          (_report?.deliverableId.isEmpty ?? true);
      if (needsFullFetch) {
        // Fetch full report details in background
        _loadReportData();
      } else if (_deliverable == null &&
          _report != null &&
          _report!.deliverableId.isNotEmpty) {
        // Fetch deliverable in background without blocking initial render
        _loadDeliverable(_report!.deliverableId);
      }
    } else {
      _loadReportData();
    }
  }

  Future<void> _loadReportData() async {
    try {
      final api = BackendApiService();

      // If token is provided, use token-based endpoint
      if (widget.reviewToken != null && widget.reviewToken!.isNotEmpty) {
        final tokenResp = await api.getClientReviewByToken(widget.reviewToken!);
        if (!mounted) return;

        if (tokenResp.isSuccess && tokenResp.data != null) {
          final data = tokenResp.data!;
          final reportJson = data['report'] ?? data;
          final loadedReport = SignOffReport.fromJson(reportJson);

          Deliverable? loadedDeliverable;
          if (data['deliverable'] != null) {
            try {
              loadedDeliverable = Deliverable.fromJson(data['deliverable']);
            } catch (_) {}
          }

          // Update sprint performance data if provided
          if (data['performanceMetrics'] != null) {
            final perfData = data['performanceMetrics'];
            final updatedReport = loadedReport.copyWith(
              sprintPerformanceData:
                  perfData is String ? perfData : jsonEncode(perfData),
            );
            setState(() {
              _report = updatedReport;
              _deliverable = loadedDeliverable;
            });
          } else {
            setState(() {
              _report = loadedReport;
              _deliverable = loadedDeliverable;
            });
          }
        } else {
          // Token expired or invalid
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text(tokenResp.error ?? 'Invalid or expired review link'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          setState(() {
            _report = null;
            _deliverable = null;
          });
        }
        return;
      }

      // Standard authenticated endpoint
      final reportResp = await api.getSignOffReport(widget.reportId);
      if (!mounted) return;
      if (reportResp.isSuccess && reportResp.data != null) {
        final reportJson = reportResp.data!['data'] ??
            reportResp.data!['report'] ??
            reportResp.data!;
        final loadedReport = SignOffReport.fromJson(reportJson);
        Deliverable? loadedDeliverable;
        if (loadedReport.deliverableId.isNotEmpty) {
          final delivResp =
              await api.getDeliverable(loadedReport.deliverableId);
          if (delivResp.isSuccess && delivResp.data != null) {
            final dJson = delivResp.data!['data'] ??
                delivResp.data!['deliverable'] ??
                delivResp.data!;
            loadedDeliverable = Deliverable.fromJson(dJson);
          }
        }
        setState(() {
          _report = loadedReport;
          _deliverable = loadedDeliverable;
        });
      } else {
        setState(() {
          _report = null;
          _deliverable = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _report = null;
        _deliverable = null;
      });
    }
  }

  Future<void> _loadDeliverable(String deliverableId) async {
    try {
      final api = BackendApiService();
      final delivResp = await api.getDeliverable(deliverableId);
      if (!mounted) return;
      if (delivResp.isSuccess && delivResp.data != null) {
        final dJson = delivResp.data!['data'] ??
            delivResp.data!['deliverable'] ??
            delivResp.data!;
        setState(() {
          _deliverable = Deliverable.fromJson(dJson);
        });
      }
    } catch (_) {}
  }

  Future<void> _submitApproval() async {
    if (_selectedAction.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an action (Approve or Request Changes)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedAction == 'changeRequest' &&
        _changeRequestController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide details for the change request'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final backendService = BackendApiService();
      if (_selectedAction == 'approve') {
        String? signature = _capturedSignature;
        signature ??= await _signatureKey.currentState?.getSignature();
        if (signature == null || signature.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Digital signature is required to approve this report.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        // If using token-based access, pass token in request
        final reportId = widget.reviewToken != null && widget.reportId.isEmpty
            ? _report?.id ?? ''
            : widget.reportId;
        final response = await backendService.approveSignOffReport(
          reportId,
          _commentController.text.isNotEmpty ? _commentController.text : null,
          signature,
          reviewToken: widget.reviewToken,
        );
        if (response.isSuccess && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report approved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _report = _report?.copyWith(status: ReportStatus.approved);
          });
          context.go('/enhanced-client-review/${widget.reportId}');
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to approve report: ${response.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else if (_selectedAction == 'changeRequest') {
        // If using token-based access, pass token in request
        final reportId = widget.reviewToken != null && widget.reportId.isEmpty
            ? _report?.id ?? ''
            : widget.reportId;
        final response = await backendService.requestSignOffChanges(
          reportId,
          _changeRequestController.text,
          reviewToken: widget.reviewToken,
        );
        if (response.isSuccess && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Change request submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _report = _report?.copyWith(status: ReportStatus.changeRequested);
          });
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Failed to submit change request: ${response.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting review: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
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
            if (_deliverable == null &&
                (_report?.deliverableId.isEmpty ?? true)) ...[
              buildStatusItem('Linked Deliverable', 'None'),
            ] else if (_deliverable == null) ...[
              const LinearProgressIndicator(),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: buildStatusItem('Title', _deliverable!.title),
                  ),
                  Expanded(
                    child: buildStatusItem(
                        'Status', _deliverable!.statusDisplayName),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: buildStatusItem(
                        'Due Date', formatDate(_deliverable!.dueDate)),
                  ),
                  Expanded(
                    child: buildStatusItem(
                        'Submitted By', _deliverable!.submittedBy ?? 'Unknown'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildStatusItem(String label, String value) {
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
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
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
                      'Sign-Off Report',
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
    if (_report?.sprintPerformanceData == null ||
        _report!.sprintPerformanceData!.isEmpty) {
      return const SizedBox.shrink();
    }

    try {
      final List<dynamic> rawData = jsonDecode(_report!.sprintPerformanceData!);
      final List<Map<String, dynamic>> sprints =
          rawData.map((e) => Map<String, dynamic>.from(e)).toList();

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
          // Burndown Chart
          SizedBox(
            height: 300,
            child: SprintPerformanceChart(
              sprints: sprints,
              chartType: 'burndown',
            ),
          ),
          const SizedBox(height: 16),
          // Burnup Chart
          SizedBox(
            height: 300,
            child: SprintPerformanceChart(
              sprints: sprints,
              chartType: 'burnup',
            ),
          ),
          const SizedBox(height: 16),
          // Committed vs Completed (Scope Completion)
          SizedBox(
            height: 300,
            child: SprintPerformanceChart(
              sprints: sprints,
              chartType: 'committed_vs_completed',
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

  Widget _buildChangeRequestHistory() {
    if ((_report?.changeRequestHistory == null ||
            _report!.changeRequestHistory!.isEmpty) &&
        _report?.changeRequestDetails == null) {
      return const SizedBox.shrink();
    }

    final history = _report?.changeRequestHistory ?? [];
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
            if (historyList.isNotEmpty)
              const Divider(color: Colors.orange, height: 24),
          ],
          ...historyList.map((item) {
            final i = item is Map ? item : {'details': item.toString()};
            return _buildHistoryItem(
              details: i['details'] ?? '',
              date: i['requestedAt'] != null
                  ? DateTime.parse(i['requestedAt'])
                  : null,
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
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontStyle: FontStyle.italic),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget buildReviewActions() {
    return Card(
      color: FlownetColors.graphiteGray,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review Decision',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: FlownetColors.pureWhite,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Approve',
                        style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Accept the deliverable as complete',
                        style: TextStyle(color: Colors.grey)),
                    value: 'approve',
                    // ignore: deprecated_member_use
                    groupValue: _selectedAction,
                    // ignore: deprecated_member_use
                    onChanged: (value) {
                      setState(() {
                        _selectedAction = value!;
                      });
                    },
                    activeColor: Colors.green,
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Request Changes',
                        style: TextStyle(color: Colors.white)),
                    subtitle: const Text(
                        'Request modifications before approval',
                        style: TextStyle(color: Colors.grey)),
                    value: 'changeRequest',
                    // ignore: deprecated_member_use
                    groupValue: _selectedAction,
                    // ignore: deprecated_member_use
                    onChanged: (value) {
                      setState(() {
                        _selectedAction = value!;
                      });
                    },
                    activeColor: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Comments (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.comment),
                hintText: 'Add any additional comments...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            if (_selectedAction == 'changeRequest') ...[
              TextFormField(
                controller: _changeRequestController,
                decoration: const InputDecoration(
                  labelText: 'Change Request Details *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit),
                  hintText:
                      'List the required changes (e.g.,\n1. Update charts\n2. Fix typo in summary)',
                ),
                maxLines: 6,
                validator: (value) {
                  if (_selectedAction == 'changeRequest' &&
                      (value?.isEmpty ?? true)) {
                    return 'Please provide change request details';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildDigitalSignatureSection() {
    return Card(
      color: FlownetColors.graphiteGray,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Digital Signature',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: FlownetColors.pureWhite,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SignatureCaptureWidget(
              key: _signatureKey,
              allowSignatureReuse: true,
              showAuditInfo: true,
              reportId: _report?.id,
              onSignatureCaptured: (sig) {
                setState(() {
                  _capturedSignature = sig;
                });
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitApproval,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedAction == 'approve'
                      ? Colors.green
                      : Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _selectedAction == 'approve'
                            ? 'Approve Report'
                            : 'Submit Change Request',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String formatDate(DateTime date) {
    final tz = date.toUtc().add(const Duration(hours: 2));
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${two(tz.day)}/${two(tz.month)}/${tz.year} ${two(tz.hour)}:${two(tz.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlownetColors.charcoalBlack,
      appBar: AppBar(
        title: const FlownetLogo(),
        backgroundColor: FlownetColors.charcoalBlack,
        foregroundColor: FlownetColors.pureWhite,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Client Review & Approval',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: FlownetColors.pureWhite,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Review the deliverable and provide your decision',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: FlownetColors.coolGray,
                  ),
            ),
            const SizedBox(height: 24),

            // Deliverable Status Card
            buildStatusCard(),
            const SizedBox(height: 24),

            // Report Content
            if (_report == null || (_report!.reportContent.isEmpty))
              const Center(child: CircularProgressIndicator())
            else
              buildReportContent(),
            const SizedBox(height: 24),

            // Change Request History
            if (_report?.changeRequestHistory?.isNotEmpty == true ||
                _report?.changeRequestDetails != null)
              _buildChangeRequestHistory(),

            // Review Actions
            if (_report?.status == ReportStatus.approved)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Report Approved',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const Text(
                            'This report has been approved and sealed.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          if (_report?.approvedBy != null)
                            Text(
                              'Approved by: ${_report!.approvedBy} on ${formatDate(_report!.approvedAt ?? DateTime.now())}',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else if (_report?.status == ReportStatus.changeRequested)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Change Requested',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const Text(
                            'Changes have been requested. The team will review and resubmit.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          if (_report?.changeRequestDetails != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _report!.changeRequestDetails!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              buildReviewActions(),
              const SizedBox(height: 24),
              buildDigitalSignatureSection(),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _changeRequestController.dispose();
    super.dispose();
  }
}
