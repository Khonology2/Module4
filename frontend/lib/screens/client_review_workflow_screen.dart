import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sign_off_report.dart';
import '../models/user_role.dart';
import '../services/sign_off_report_service.dart';
import '../services/deliverable_service.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../theme/flownet_theme.dart';
import '../widgets/flownet_logo.dart';
import '../widgets/signature_capture_widget.dart';
import '../widgets/signature_display_widget.dart';
import '../services/docusign_service.dart';
import '../services/backend_api_service.dart';
import '../services/notification_service.dart';
import '../models/notification_item.dart';
import '../services/realtime_service.dart';

class ClientReviewWorkflowScreen extends ConsumerStatefulWidget {
  final String reportId;

  const ClientReviewWorkflowScreen({
    super.key,
    required this.reportId,
  });

  @override
  ConsumerState<ClientReviewWorkflowScreen> createState() =>
      _ClientReviewWorkflowScreenState();
}

class _ClientReviewWorkflowScreenState
    extends ConsumerState<ClientReviewWorkflowScreen> {
  final _commentController = TextEditingController();
  final _changeRequestController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final GlobalKey<SignatureCaptureWidgetState> _signatureKey =
      GlobalKey<SignatureCaptureWidgetState>();

  final SignOffReportService _reportService =
      SignOffReportService(AuthService());
  final DeliverableService _deliverableService = DeliverableService();
  final DocuSignService _docuSignService = DocuSignService(ApiClient());
  final BackendApiService _apiService = BackendApiService();

  SignOffReport? _report;
  Map<String, dynamic>? _deliverable;
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _selectedAction; // 'approve' | 'request_changes' | 'reject'
  List<Map<String, dynamic>> _signatures = []; // Store digital signatures
  bool _docuSignEnabled = false;
  bool _useDocuSign = false;
  String _signerEmail = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await AuthService().initialize();
      } catch (_) {}
      try {
        await _apiService.initialize();
      } catch (_) {}
      await _loadReportData();
      await _loadDocuSignConfig();
    });
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);

    try {
      // Load report
      final reportResponse =
          await _reportService.getSignOffReport(widget.reportId);
      if (reportResponse.isSuccess && reportResponse.data != null) {
        // ApiClient already extracts the 'data' field, so response.data is the report object directly
        // But check if it's nested in a 'data' key or is the report directly
        final data =
            reportResponse.data is Map && reportResponse.data!['data'] != null
                ? reportResponse.data!['data'] as Map<String, dynamic>
                : reportResponse.data as Map<String, dynamic>;

        final reviews = data['reviews'] as List? ?? [];

        setState(() {
          _report = SignOffReport.fromJson(Map<String, dynamic>.from(data));

          _reviews = reviews.cast<Map<String, dynamic>>();

          // Load deliverable details
          if (_report!.deliverableId.isNotEmpty) {
            _loadDeliverable(_report!.deliverableId);
          }
        });

        // Load digital signatures
        await _loadSignatures();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading report: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSignatures() async {
    try {
      final ApiClient apiClient = ApiClient();
      await apiClient.initialize();
      final response = await apiClient
          .get('/sign-off-reports/${widget.reportId}/signatures');

      if (response.isSuccess && response.data != null) {
        final raw = response.data;
        List<dynamic> items = const [];
        if (raw is List) {
          items = raw;
        } else if (raw is Map) {
          final d = raw['data'];
          if (d is List) {
            items = d;
          } else if (d is Map) {
            final inner = d['items'] ?? d['data'];
            if (inner is List) items = inner;
          }
        }
        setState(() {
          _signatures = items
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
        debugPrint('✅ Loaded ${_signatures.length} signatures for report');
      }
    } catch (e) {
      debugPrint('Error loading signatures: $e');
      // Don't show error to user - signatures are optional display
    }
  }

  Future<void> _loadDeliverable(String deliverableId) async {
    try {
      final response = await _deliverableService.getDeliverables();
      if (response.isSuccess && response.data != null) {
        final deliverables = response.data!['deliverables'] as List;
        final deliverable = deliverables.firstWhere(
          (d) => d['id'].toString() == deliverableId.toString(),
          orElse: () => null,
        );
        if (deliverable != null) {
          setState(() => _deliverable = deliverable as Map<String, dynamic>);
        }
      }
    } catch (e) {
      // Silently fail - deliverable is optional
    }
  }

  Future<void> _loadDocuSignConfig() async {
    final ok = await _docuSignService.loadConfiguration();
    if (mounted) {
      setState(() => _docuSignEnabled = ok);
    }
  }

  Future<void> _handleApproval() async {
    if (_selectedAction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an action'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      ApiResponse response;

      if (_selectedAction == 'approve') {
        if (_docuSignEnabled && _useDocuSign) {
          if (_signerEmail.trim().isEmpty) {
            setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please enter the signer email for DocuSign'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
          final envelopeId = await _docuSignService.createEnvelopeForReport(
            reportId: widget.reportId,
            signerEmail: _signerEmail.trim(),
            signerName: AuthService().currentUser?.name ?? 'Signer',
            reportTitle: _report?.displayTitle ?? 'Sign-Off Report',
            reportContent: _report?.reportContent ?? '',
          );
          if (envelopeId != null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('DocuSign envelope created and sent'),
                  backgroundColor: Colors.green,
                ),
              );
            }
            response = ApiResponse.success({'status': 'docusign_sent'}, 200);
          } else {
            response = ApiResponse.error('Failed to create DocuSign envelope');
          }
        } else {
          String? signature;
          if (_signatureKey.currentState != null) {
            signature = await _signatureKey.currentState!.getSignature();
          }
          if (signature == null || signature.isEmpty) {
            if (mounted) {
              setState(() => _isSubmitting = false);
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
          response = await _reportService.approveReport(
            widget.reportId,
            comment: _commentController.text.trim().isNotEmpty
                ? _commentController.text.trim()
                : null,
            digitalSignature: signature,
          );
        }
      } else if (_selectedAction == 'request_changes') {
        if (_changeRequestController.text.trim().isEmpty) {
          if (mounted) {
            setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Change request details are required.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        String? signature;
        if (_signatureKey.currentState != null) {
          signature = await _signatureKey.currentState!.getSignature();
        }
        if (signature == null || signature.isEmpty) {
          if (mounted) {
            setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Digital signature is required to request changes for this report.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        response = await _reportService.requestChanges(
          widget.reportId,
          changeRequestDetails: _changeRequestController.text.trim().isNotEmpty
              ? _changeRequestController.text.trim()
              : null,
          digitalSignature: signature,
        );
      } else {
        String? signature;
        if (_signatureKey.currentState != null) {
          signature = await _signatureKey.currentState!.getSignature();
        }
        if (signature == null || signature.isEmpty) {
          if (mounted) {
            setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Digital signature is required to reject this report.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        response = await _reportService.rejectReport(
          widget.reportId,
          comment: _commentController.text.trim().isNotEmpty
              ? _commentController.text.trim()
              : null,
          digitalSignature: signature,
        );
      }

      if (response.isSuccess) {
        // Reload signatures after approval to show the new signature
        if (_selectedAction == 'approve' || _selectedAction == 'request_changes' || _selectedAction == 'reject') {
          await _loadSignatures();
        }
        try {
          final ns = NotificationService();
          final token = AuthService().accessToken;
          if (token != null) ns.setAuthToken(token);
          final actor = AuthService().currentUser?.name ?? 'User';
          final title = _selectedAction == 'approve'
              ? 'Report Approved'
              : _selectedAction == 'reject'
                  ? 'Report Rejected'
                  : 'Report Changes Requested';
          final message = _selectedAction == 'approve'
              ? '$actor approved "${_report?.displayTitle ?? 'Report'}"'
              : _selectedAction == 'reject'
                  ? '$actor rejected "${_report?.displayTitle ?? 'Report'}"'
                  : '$actor requested changes for "${_report?.displayTitle ?? 'Report'}"';
          final type = _selectedAction == 'approve'
              ? NotificationType.reportApproved
              : NotificationType.reportChangesRequested;
          await ns.createNotification(
              title: title, message: message, type: type);
        } catch (_) {}
        try {
          final rt = RealtimeService();
          await rt.initialize(authToken: AuthService().accessToken);
          final event = _selectedAction == 'approve'
              ? 'report_approved'
              : _selectedAction == 'reject'
                  ? 'report_rejected'
                  : 'report_change_requested';
          rt.emit(event, {
            'reportId': widget.reportId,
            'title': _report?.displayTitle ?? 'Report',
          });
          rt.emit('approval_updated', {
            'reportId': widget.reportId,
          });
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_selectedAction == 'approve'
                  ? '✅ Report approved successfully!'
                  : _selectedAction == 'reject'
                      ? 'Report rejected successfully!'
                      : 'Change request submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          await _loadReportData();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting review: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _generateCommentSuggestion() async {
    if (_report == null) return;
    setState(() => _isSubmitting = true);
    try {
      final messages = [
        {
          'role': 'system',
          'content':
              'Generate a concise, professional client approval comment based on the report.'
        },
        {
          'role': 'user',
          'content':
              '${_report!.displayTitle}\n\n${_report!.reportContent}\n\nKnown limitations: ${_report!.knownLimitations ?? '-'}\nNext steps: ${_report!.nextSteps ?? '-'}'
        }
      ];
      final resp =
          await _apiService.aiChat(messages, temperature: 0.6, maxTokens: 120);
      if (resp.isSuccess && resp.data != null) {
        final data = resp.data as Map<String, dynamic>;
        final content =
            (data['content'] ?? (data['data']?['content']))?.toString() ?? '';
        if (content.isNotEmpty) {
          _commentController.text = content;
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _generateChangeRequestSuggestion() async {
    if (_report == null) return;
    setState(() => _isSubmitting = true);
    try {
      final messages = [
        {
          'role': 'system',
          'content':
              'Draft a clear, actionable change request detailing improvements needed.'
        },
        {
          'role': 'user',
          'content':
              '${_report!.displayTitle}\n\n${_report!.reportContent}\n\nFocus on gaps, risks, and necessary updates.'
        }
      ];
      final resp =
          await _apiService.aiChat(messages, temperature: 0.7, maxTokens: 160);
      if (resp.isSuccess && resp.data != null) {
        final data = resp.data as Map<String, dynamic>;
        final content =
            (data['content'] ?? (data['data']?['content']))?.toString() ?? '';
        if (content.isNotEmpty) {
          _changeRequestController.text = content;
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildReportDisplay() {
    if (_report == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Deliverable Summary
        if (_deliverable != null) ...[
          Card(
            color: FlownetColors.graphiteGray,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.assignment,
                          color: FlownetColors.electricBlue),
                      const SizedBox(width: 8),
                      Text(
                        'Deliverable Summary',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: FlownetColors.pureWhite,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _deliverable!['title'] as String? ?? 'Untitled',
                    style: const TextStyle(
                      color: FlownetColors.pureWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_deliverable!['description'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _deliverable!['description'].toString(),
                      style: const TextStyle(color: FlownetColors.coolGray),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Chip(
                        label: Text(
                          (_deliverable!['status'] as String?) ?? 'Unknown',
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor:
                            FlownetColors.electricBlue.withValues(alpha: 0.2),
                      ),
                      const SizedBox(width: 8),
                      if (_deliverable!['priority'] != null)
                        Chip(
                          label: Text(
                            _deliverable!['priority'].toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: FlownetColors.graphiteGray,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Report Title
        Text(
          _report!.displayTitle,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: FlownetColors.pureWhite,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),

        // Report Content
        Card(
          color: FlownetColors.graphiteGray,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.description, color: FlownetColors.electricBlue),
                    SizedBox(width: 8),
                    Text(
                      'Report Content',
                      style: TextStyle(
                        color: FlownetColors.pureWhite,
                        fontSize: 18,
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
                      color: Colors.black87,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Known Limitations
        if (_report!.knownLimitations != null &&
            _report!.knownLimitations!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            color: FlownetColors.graphiteGray,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'Known Limitations',
                        style: TextStyle(
                          color: FlownetColors.pureWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _report!.knownLimitations!,
                    style: const TextStyle(color: FlownetColors.coolGray),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Next Steps
        if (_report!.nextSteps != null && _report!.nextSteps!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            color: FlownetColors.graphiteGray,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.arrow_forward,
                          color: FlownetColors.electricBlue),
                      SizedBox(width: 8),
                      Text(
                        'Next Steps',
                        style: TextStyle(
                          color: FlownetColors.pureWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _report!.nextSteps!,
                    style: const TextStyle(color: FlownetColors.coolGray),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Previous Reviews
        if (_reviews.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'Previous Reviews',
            style: TextStyle(
              color: FlownetColors.pureWhite,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ..._reviews.map(
            (review) => Card(
              color: FlownetColors.graphiteGray,
              child: ListTile(
                leading: Icon(
                  review['status'] == 'approved'
                      ? Icons.check_circle
                      : Icons.edit,
                  color: review['status'] == 'approved'
                      ? Colors.green
                      : Colors.orange,
                ),
                title: Text(
                  (review['reviewerName'] ??
                              review['reviewer_name'] ??
                              review['reviewer'])
                          ?.toString() ??
                      'Unknown Reviewer',
                  style: const TextStyle(color: FlownetColors.pureWhite),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['status'] == 'approved'
                          ? 'Approved'
                          : 'Requested Changes',
                      style: TextStyle(
                        color: review['status'] == 'approved'
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                    if (review['feedback'] != null)
                      Text(
                        review['feedback'] as String,
                        style: const TextStyle(color: FlownetColors.coolGray),
                      ),
                  ],
                ),
                trailing: review['approved_at'] != null
                    ? Text(
                        _formatDate(DateTime.parse(review['approved_at'])),
                        style: const TextStyle(
                            color: FlownetColors.coolGray, fontSize: 12),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatDate(DateTime date) {
    final tz = date.toUtc().add(const Duration(hours: 2));
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${two(tz.day)}/${two(tz.month)}/${tz.year} ${two(tz.hour)}:${two(tz.minute)}';
  }

  String _getSignatureTitle(String? role) {
    switch (role?.toLowerCase()) {
      case 'deliverylead':
        return 'Delivery Lead Signature';
      case 'clientreviewer':
        return 'Client Approval Signature';
      case 'systemadmin':
        return 'System Admin Signature';
      default:
        return 'Digital Signature';
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _changeRequestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userRole = AuthService().currentUser?.role;
    final canReview = userRole == UserRole.clientReviewer || userRole == UserRole.client;
    final isApproved = _report?.status == ReportStatus.approved;

    return Scaffold(
      backgroundColor: FlownetColors.charcoalBlack,
      appBar: AppBar(
        title: const FlownetLogo(),
        backgroundColor: FlownetColors.charcoalBlack,
        foregroundColor: FlownetColors.pureWhite,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReportDisplay(),

                  // Review Section (only if can review and not already approved)
                  if (canReview &&
                      !isApproved &&
                      (_report?.status == ReportStatus.submitted ||
                          _report?.status == ReportStatus.underReview)) ...[
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Client Review & Approval',
                            style: TextStyle(
                              color: FlownetColors.pureWhite,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Action Selection
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment<String>(
                                value: 'approve',
                                label: Text('Approve'),
                                icon: Icon(Icons.check_circle),
                              ),
                              ButtonSegment<String>(
                                value: 'request_changes',
                                label: Text('Request Changes'),
                                icon: Icon(Icons.edit_note),
                              ),
                              ButtonSegment<String>(
                                value: 'reject',
                                label: Text('Reject'),
                                icon: Icon(Icons.cancel),
                              ),
                            ],
                            selected: <String>{
                              if (_selectedAction != null) _selectedAction!
                            },
                            emptySelectionAllowed: true,
                            onSelectionChanged: (Set<String> newSelection) {
                              setState(() {
                                _selectedAction = newSelection.isEmpty
                                    ? null
                                    : newSelection.first;
                              });
                            },
                            style: SegmentedButton.styleFrom(
                              selectedForegroundColor: FlownetColors.pureWhite,
                              foregroundColor: FlownetColors.coolGray,
                            ),
                          ),

                          if (_selectedAction == 'approve' ||
                              _selectedAction == 'reject') ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _commentController,
                              decoration: const InputDecoration(
                                labelText: 'Comment (Optional)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.comment),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 8),
                            if (_selectedAction == 'approve') ...[
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: _isSubmitting
                                      ? null
                                      : _generateCommentSuggestion,
                                  icon: const Icon(Icons.auto_awesome),
                                  label: const Text('Suggest with AI'),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                            if (_selectedAction == 'approve') ...[
                              if (_docuSignEnabled) ...[
                                const SizedBox(height: 8),
                                SwitchListTile(
                                  value: _useDocuSign,
                                  onChanged: (v) =>
                                      setState(() => _useDocuSign = v),
                                  title: const Text('Use DocuSign (Certified)'),
                                  subtitle: const Text(
                                      'Send a DocuSign envelope to signer email'),
                                  activeThumbColor: FlownetColors.electricBlue,
                                ),
                                if (_useDocuSign) ...[
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    decoration: const InputDecoration(
                                      labelText: 'Signer Email',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.email),
                                    ),
                                    onChanged: (v) => _signerEmail = v,
                                  ),
                                ] else ...[
                                  SignatureCaptureWidget(
                                    key: _signatureKey,
                                    existingSignature: _report?.digitalSignature,
                                    allowSignatureReuse: true,
                                    showAuditInfo: true,
                                    reportId: _report?.id,
                                  ),
                                ],
                              ] else ...[
                                SignatureCaptureWidget(
                                  key: _signatureKey,
                                  existingSignature: _report?.digitalSignature,
                                  allowSignatureReuse: true,
                                  showAuditInfo: true,
                                  reportId: _report?.id,
                                ),
                              ],
                            ],
                          ],

                          // Change Request Details (optional)
                          if (_selectedAction == 'request_changes') ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _changeRequestController,
                              decoration: const InputDecoration(
                                labelText: 'Change Request Details',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.edit_note),
                                helperText:
                                    'Required. Please provide clear details about what changes are needed',
                              ),
                              maxLines: 6,
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : _generateChangeRequestSuggestion,
                                icon: const Icon(Icons.auto_awesome),
                                label: const Text('Suggest with AI'),
                              ),
                            ),
                          ],

                          if (_selectedAction == 'request_changes' ||
                              _selectedAction == 'reject') ...[
                            const SizedBox(height: 16),
                            SignatureCaptureWidget(
                              key: _signatureKey,
                              existingSignature: _report?.digitalSignature,
                              allowSignatureReuse: true,
                              showAuditInfo: true,
                              reportId: _report?.id,
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isSubmitting ? null : _handleApproval,
                              icon: Icon(
                                _selectedAction == 'approve'
                                    ? Icons.check_circle
                                    : _selectedAction == 'reject'
                                        ? Icons.cancel
                                        : Icons.edit_note,
                              ),
                              label: Text(
                                _isSubmitting
                                    ? 'Submitting...'
                                    : _selectedAction == 'approve'
                                        ? 'Approve Report'
                                        : _selectedAction == 'reject'
                                            ? 'Reject Report'
                                            : 'Request Changes',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _selectedAction == 'approve'
                                    ? Colors.green
                                    : _selectedAction == 'reject'
                                        ? Colors.red
                                        : Colors.orange,
                                foregroundColor: FlownetColors.pureWhite,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Approved Status Banner with Signatures
                  if (isApproved) ...[
                    const SizedBox(height: 32),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green, size: 32),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This report has been approved and sealed. No further changes are allowed.',
                              style:
                                  TextStyle(color: Colors.green, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Display all digital signatures
                    if (_signatures.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Digital Signatures',
                        style: TextStyle(
                          color: FlownetColors.pureWhite,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Display each signature
                      ..._signatures.map((sig) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: SignatureDisplayWidget(
                            signatureData: sig['signature_data'] as String?,
                            signerName:
                                sig['signer_name'] as String? ?? 'Unknown',
                            signerRole:
                                sig['signer_role'] as String? ?? 'unknown',
                            signedDate:
                                DateTime.parse(sig['signed_at'] as String),
                            title: _getSignatureTitle(
                                sig['signer_role'] as String?),
                            isVerified: sig['is_valid'] as bool? ?? true,
                            signatureType:
                                sig['signature_type'] as String? ?? 'manual',
                          ),
                        );
                      }),
                    ],
                  ],

                  // Change Requested Status
                  if (_report?.status == ReportStatus.changeRequested) ...[
                    const SizedBox(height: 32),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        border: Border.all(color: Colors.orange),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.edit_note,
                                  color: Colors.orange, size: 32),
                              SizedBox(width: 12),
                              Text(
                                'Changes Requested',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'This report has been reopened for changes. Please review the feedback and update the report accordingly.',
                            style: TextStyle(color: Colors.orange),
                          ),
                          if (_reviews.isNotEmpty &&
                              _reviews.last['feedback'] != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _reviews.last['feedback'] as String,
                                style: const TextStyle(color: Colors.orange),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
