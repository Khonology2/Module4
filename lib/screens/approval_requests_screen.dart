import 'dart:async';
import 'package:flutter/material.dart';
import '../models/approval_request.dart' as core;
import '../services/approval_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/sign_off_report_service.dart';
import '../services/realtime_service.dart';
import '../theme/flownet_theme.dart';
import '../widgets/flownet_logo.dart';
import '../utils/date_utils.dart' as du;
import 'package:go_router/go_router.dart';
import 'client_review_workflow_screen.dart';
import '../widgets/app_modal.dart';

class ApprovalRequestsScreen extends StatefulWidget {
  const ApprovalRequestsScreen({super.key});

  @override
  State<ApprovalRequestsScreen> createState() => _ApprovalRequestsScreenState();
}

class _ApprovalRequestsScreenState extends State<ApprovalRequestsScreen> {
  final ApprovalService _approvalService = ApprovalService(AuthService());
  final SignOffReportService _reportService = SignOffReportService(AuthService());
  RealtimeService? _realtime;
  List<core.ApprovalRequest> _requests = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'all';
  String _selectedPriority = 'all';
  String _selectedCategory = 'all';
String _selectedSprintId = 'all';
  String _selectedDeliverableId = 'all';
  List<dynamic> _deliverables = [];
  List<Map<String, dynamic>> _sprints = [];

  String _formatSaDate(DateTime date) {
    return du.DateUtils.formatDateTime(date);
  }

  @override
  void initState() {
    super.initState();
Future.microtask(() async {
      try {
        await AuthService().initialize();
      } catch (_) {}
      try {
        final token = AuthService().accessToken;
        if (token != null && token.isNotEmpty) {
          _realtime = RealtimeService();
          await _realtime!.initialize(authToken: token);
          _setupRealtimeListeners();
        }
      } catch (_) {}
      if (!mounted) return;
      await _loadFilters();
      await _loadApprovalRequests();
    });
  }

  Future<void> _loadApprovalRequests() async {
    setState(() => _isLoading = true);
    
    try {
      final statusParam = _selectedStatus != 'all' ? _selectedStatus : null;
      final priorityParam = _selectedPriority != 'all' ? _selectedPriority : null;
      final categoryParam = _selectedCategory != 'all' ? _selectedCategory : null;
      final deliverableParam = _selectedDeliverableId != 'all' ? _selectedDeliverableId : null;
      final response = await _approvalService.getApprovalRequests(
        status: statusParam,
        priority: priorityParam,
        category: categoryParam,
        deliverableId: deliverableParam,
      );
      
      if (response.isSuccess) {
        final raw = response.data;
        final items = raw is Map ? (raw['requests'] as List? ?? const []) : const [];
        final list = items.map((item) {
          if (item is core.ApprovalRequest) return item;
          if (item is Map) {
            return core.ApprovalRequest.fromJson(item.cast<String, dynamic>());
          }
          return core.ApprovalRequest.fromJson(<String, dynamic>{});
        }).toList();
        final merged = await _mergeSignOffFallback(list);
        setState(() {
          _requests = merged;
        });
      } else {
        _showErrorSnackBar('Failed to load approval requests: ${response.error}');
      }
    } catch (e) {
      _showErrorSnackBar('Error loading approval requests: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<core.ApprovalRequest>> _mergeSignOffFallback(List<core.ApprovalRequest> base) async {
    try {
      final reportsRespSubmitted = await _reportService.getSignOffReports(status: 'submitted');
      final reportsRespUnderReview = await _reportService.getSignOffReports(status: 'under_review');
      final reportsRespApproved = await _reportService.getSignOffReports(status: 'approved');
      final reportsRespChanges = await _reportService.getSignOffReports(status: 'change_requested');

      final builder = <core.ApprovalRequest>[];
      void addFrom(dynamic raw, String statusOverride) {
        if (raw == null) return;
        final list = raw is List ? raw : (raw is Map ? (raw['data'] ?? raw['reports'] ?? raw['items'] ?? []) : []);
        for (final e in list.whereType<Map>()) {
          final m = e.cast<String, dynamic>();
          final idStr = (m['id'] ?? m['report_id'] ?? '').toString();
          final title = (m['reportTitle'] ?? m['report_title'] ?? (m['content'] is Map ? ((m['content'] as Map)['reportTitle'] ?? (m['content'] as Map)['title']) : null) ?? m['title'] ?? 'Sign-Off Report').toString();
          final desc = (m['reportContent'] ?? m['report_content'] ?? (m['content'] is Map ? ((m['content'] as Map)['reportContent'] ?? (m['content'] as Map)['content']) : null) ?? '').toString();
          final createdBy = (m['createdBy'] ?? m['created_by'] ?? '').toString();
          final createdByName = (m['createdByName'] ?? m['created_by_name'] ?? '').toString();
          final createdAtStr = (m['created_at'] ?? m['createdAt'] ?? '').toString();
          DateTime requestedAt;
          final parsed = DateTime.tryParse(createdAtStr);
          requestedAt = parsed ?? DateTime.now();
          final approvedBy = (m['approvedBy'] ?? m['approved_by'] ?? m['reviewedBy'] ?? m['reviewed_by'] ?? '').toString();
          final reviewedAtStr = (m['approvedAt'] ?? m['approved_at'] ?? m['reviewedAt'] ?? m['reviewed_at'] ?? '').toString();
          final reviewedAt = DateTime.tryParse(reviewedAtStr);
          final comment = (m['clientComment'] ?? m['client_comment'] ?? m['changeRequestDetails'] ?? m['change_request_details'] ?? '').toString();
          final deliverableId = (m['deliverableId'] ?? m['deliverable_id'] ?? '').toString();
          final deliverableTitle = (m['deliverableTitle'] ??
                  m['deliverable_title'] ??
                  m['deliverableName'] ??
                  m['deliverable_name'] ??
                  (m['deliverable'] is Map
                      ? (m['deliverable']['title'] ??
                              m['deliverable']['name'] ??
                              m['deliverable']['deliverableTitle'])
                          ?.toString()
                      : null) ??
                  '')
              .toString();
          final deliverableDescription = (m['deliverableDescription'] ??
                  m['deliverable_description'] ??
                  (m['deliverable'] is Map
                      ? (m['deliverable']['description'] ??
                              m['deliverable']['deliverableDescription'])
                          ?.toString()
                      : null) ??
                  '')
              .toString();
          String status = statusOverride;
          final s = (m['status'] ?? '').toString().toLowerCase();
          if (s.isNotEmpty) {
            if (s == 'submitted') {
              status = 'pending';
            // ignore: curly_braces_in_flow_control_structures
            } else if (s == 'approved') status = 'approved';
            // ignore: curly_braces_in_flow_control_structures
            else if (s.contains('change')) status = 'rejected';
          }
          builder.add(core.ApprovalRequest(
            id: 'report:$idStr',
            title: title,
            description: desc,
            requestedBy: createdBy,
            requestedByName: createdByName.isNotEmpty ? createdByName : createdBy,
            requestedAt: requestedAt,
            status: status,
            reviewedBy: approvedBy.isNotEmpty ? approvedBy : null,
            reviewedByName: null,
            reviewedAt: reviewedAt,
            reviewReason: comment.isNotEmpty ? comment : null,
            priority: 'medium',
            category: 'Sign-off Report',
            deliverableId: deliverableId.isNotEmpty ? deliverableId : null,
            deliverableTitle: deliverableTitle.isNotEmpty ? deliverableTitle : null,
            deliverableDescription: deliverableDescription.isNotEmpty ? deliverableDescription : null,
            evidenceLinks: [],
            definitionOfDone: [],
          ));
        }
      }

      if (reportsRespSubmitted.isSuccess) addFrom(reportsRespSubmitted.data, 'pending');
      if (reportsRespUnderReview.isSuccess) addFrom(reportsRespUnderReview.data, 'pending');
      if (reportsRespApproved.isSuccess) addFrom(reportsRespApproved.data, 'approved');
      if (reportsRespChanges.isSuccess) addFrom(reportsRespChanges.data, 'rejected');

      final seen = <String>{};
      final merged = <core.ApprovalRequest>[];
      for (final r in [...builder, ...base]) {
        final key = '${r.id}:${r.deliverableId ?? ''}:${r.status}';
        if (seen.add(key)) merged.add(r);
      }
      return merged;
    } catch (_) {
      return base;
    }
  }

  void _setupRealtimeListeners() {
    _realtime?.on('approval_created', (_) => _loadApprovalRequests());
    _realtime?.on('approval_updated', (_) => _loadApprovalRequests());
    _realtime?.on('report_submitted', (_) => _loadApprovalRequests());
    _realtime?.on('report_approved', (_) => _loadApprovalRequests());
    _realtime?.on('report_change_requested', (_) => _loadApprovalRequests());
  }

  @override
  void dispose() {
    try {
      _realtime?.offAll('approval_created');
      _realtime?.offAll('approval_updated');
      _realtime?.offAll('report_submitted');
      _realtime?.offAll('report_approved');
      _realtime?.offAll('report_change_requested');
    } catch (_) {}
    super.dispose();
  }

  Future<void> _loadFilters() async {
    try {
      final deliverables = await ApiService.getDeliverables();
      final sprints = await ApiService.getSprints();
      setState(() {
        _deliverables = deliverables;
        _sprints = sprints;
      });
    } catch (_) {}
  }

  List<dynamic> get _visibleDeliverables {
    if (_selectedSprintId == 'all') return _deliverables;
    return _deliverables.where((d) {
      try {
        if (d is Map<String, dynamic>) {
          final sid = d['sprint_id'] ?? d['sprintId'];
          if (sid != null && sid.toString().isNotEmpty) {
            return sid.toString() == _selectedSprintId;
          }
          final sids = d['sprintIds'];
          if (sids is List) {
            return sids.map((e) => e.toString()).contains(_selectedSprintId);
          }
          return false;
        }
        final mirror = d;
        final sidField = (() {
          try { return mirror.sprintId; } catch (_) { return null; }
        })();
        if (sidField != null) {
          return sidField.toString() == _selectedSprintId;
        }
        final sidsField = (() {
          try { return mirror.sprintIds; } catch (_) { return null; }
        })();
        if (sidsField is List) {
          return sidsField.map((e) => e.toString()).contains(_selectedSprintId);
        }
        return false;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  bool _deliverableMatchesSprintById(String deliverableId, String sprintId) {
    try {
      final d = _deliverables.firstWhere(
        (x) {
          if (x is Map<String, dynamic>) {
            return (x['id']?.toString() ?? '') == deliverableId;
          }
          try {
            return x.id?.toString() == deliverableId || x.id.toString() == deliverableId;
          } catch (_) {
            return false;
          }
        },
        orElse: () => null,
      );
      if (d == null) return false;
      if (d is Map<String, dynamic>) {
        final sid = d['sprint_id'] ?? d['sprintId'];
        if (sid != null) return sid.toString() == sprintId;
        final sids = d['sprintIds'];
        if (sids is List) return sids.map((e) => e.toString()).contains(sprintId);
        return false;
      }
      try {
        final sidField = d.sprintId;
        if (sidField != null) return sidField.toString() == sprintId;
      } catch (_) {}
      try {
        final sidsField = d.sprintIds;
        if (sidsField is List) return sidsField.map((e) => e.toString()).contains(sprintId);
      } catch (_) {}
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openAssociatedReport(core.ApprovalRequest request) async {
    try {
      String? reportId;
      final rid = request.id;
      if (rid.toLowerCase().startsWith('report:')) {
        final parts = rid.split(':');
        if (parts.length >= 2) {
          reportId = parts.sublist(1).join(':');
        }
      }

      if ((reportId == null || reportId.isEmpty) && request.category.toLowerCase().contains('sign-off')) {
        final did = request.deliverableId?.toString() ?? '';
        if (did.isNotEmpty) {
          final resp = await _reportService.getSignOffReports(status: 'submitted', deliverableId: did);
          if (resp.isSuccess && resp.data != null) {
            final raw = resp.data;
            List<dynamic> items = const [];
            if (raw is List) {
              items = raw;
            } else if (raw is Map) {
              final d = raw['data'];
              if (d is List) {
                items = d;
              } else if (d is Map) {
                final inner = d['reports'] ?? d['items'] ?? d['data'];
                if (inner is List) items = inner;
              } else {
                final r = raw['reports'];
                if (r is List) {
                  items = r;
                } else if (r is Map) {
                  final inner = r['items'] ?? r['data'];
                  if (inner is List) items = inner;
                } else {
                  final i = raw['items'];
                  if (i is List) items = i;
                }
              }
            }
            if (items.isNotEmpty) {
              final m = items.first;
              if (m is Map) {
                final map = m.cast<String, dynamic>();
                reportId = (map['id'] ?? map['report_id'])?.toString();
              }
            }
          }
        }
      }

      if (reportId != null && reportId.isNotEmpty) {
        if (!mounted) return;
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClientReviewWorkflowScreen(reportId: reportId!),
          ),
        );
        if (result == true) {
          await _loadApprovalRequests();
        }
      } else {
        if (!mounted) return;
        GoRouter.of(context).go('/report-repository');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to open associated report: $e');
    }
  }

  List<core.ApprovalRequest> get _filteredRequests {
    return _requests.where((request) {
      final matchesSearch = _searchQuery.isEmpty ||
          request.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          request.description.toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesStatus = _selectedStatus == 'all' || 
          (_selectedStatus == 'deliverable' 
              ? request.deliverableId != null 
              : request.status == _selectedStatus);
              
      final matchesPriority = _selectedPriority == 'all' || request.priority == _selectedPriority;
      final matchesCategory = _selectedCategory == 'all' || request.category == _selectedCategory;
      final matchesDeliverable = _selectedDeliverableId == 'all' || (request.deliverableId?.toString() == _selectedDeliverableId);
      final matchesSprint = _selectedSprintId == 'all' || (
        request.deliverableId != null && _deliverableMatchesSprintById(request.deliverableId!, _selectedSprintId)
      );
      
      return matchesSearch && matchesStatus && matchesPriority && matchesCategory && matchesDeliverable && matchesSprint;
    }).toList();
  }

  String _getSprintName(core.ApprovalRequest request) {
    if (request.deliverableId == null) return '';
    try {
      final deliverableId = request.deliverableId.toString();
      final deliverable = _deliverables.firstWhere(
        (d) {
          if (d is Map<String, dynamic>) {
            return (d['id']?.toString() ?? '') == deliverableId;
          }
          try {
            return d.id?.toString() == deliverableId;
          } catch (_) {
            return false;
          }
        },
        orElse: () => <String, dynamic>{},
      );

      if (deliverable.isEmpty) return '';

      String? sprintId;
      if (deliverable is Map<String, dynamic>) {
        sprintId = (deliverable['sprint_id'] ?? deliverable['sprintId'])?.toString();
      } else {
        try {
          sprintId = deliverable.sprintId?.toString();
        } catch (_) {}
      }

      if (sprintId == null) return '';

      final sprint = _sprints.firstWhere(
        (s) {
          final sid = (s['id'] ?? s['sprint_id'] ?? s['sprintId']).toString();
          return sid == sprintId;
        },
        orElse: () => <String, dynamic>{},
      );

      if (sprint.isNotEmpty) {
        return (sprint['name'] ?? sprint['title'] ?? '').toString();
      }
    } catch (_) {}
    return '';
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: FlownetColors.crimsonRed,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: FlownetColors.electricBlue,
      ),
    );
  }

  Future<void> _approveRequest(core.ApprovalRequest request) async {
    final reason = await _showReasonDialog('Approve Request', 'Enter reason for approval:');
    if (reason != null && reason.isNotEmpty) {
      setState(() => _isLoading = true);
      
      try {
        final response = await _approvalService.approveRequest(request.id, reason);
        
        if (response.isSuccess) {
          _showSuccessSnackBar('Request approved successfully!');
          _loadApprovalRequests();
        } else {
          _showErrorSnackBar('Failed to approve request: ${response.error}');
        }
      } catch (e) {
        _showErrorSnackBar('Error approving request: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _rejectRequest(core.ApprovalRequest request) async {
    final reason = await _showReasonDialog('Reject Request', 'Enter reason for rejection:');
    if (reason != null && reason.isNotEmpty) {
      setState(() => _isLoading = true);
      
      try {
        final response = await _approvalService.rejectRequest(request.id, reason);
        
        if (response.isSuccess) {
          _showSuccessSnackBar('Request rejected successfully!');
          _loadApprovalRequests();
        } else {
          _showErrorSnackBar('Failed to reject request: ${response.error}');
        }
      } catch (e) {
        _showErrorSnackBar('Error rejecting request: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String?> _showReasonDialog(String title, String hint) async {
    final controller = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FlownetColors.graphiteGray,
        title: Text(title, style: const TextStyle(color: FlownetColors.pureWhite)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: FlownetColors.pureWhite),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: FlownetColors.coolGray),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: FlownetColors.coolGray),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: FlownetColors.electricBlue),
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: FlownetColors.coolGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: FlownetColors.electricBlue),
            child: const Text('Submit', style: TextStyle(color: FlownetColors.pureWhite)),
          ),
        ],
      ),
    );
  }

  void _showRequestDetails(core.ApprovalRequest request) {
    showAppDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FlownetColors.graphiteGray,
        title: Text(request.title, style: const TextStyle(color: FlownetColors.pureWhite)),
        content: SizedBox(
          width: 600,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Description:', style: TextStyle(color: FlownetColors.electricBlue, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(request.description, style: const TextStyle(color: FlownetColors.pureWhite)),
              
              if (request.deliverableTitle != null) ...[
                const SizedBox(height: 16),
                const Text('Deliverable:', style: TextStyle(color: FlownetColors.coolGray)),
                Text(request.deliverableTitle!, style: const TextStyle(color: FlownetColors.pureWhite)),
                if ((request.deliverableDescription ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    request.deliverableDescription!,
                    style: const TextStyle(color: FlownetColors.coolGray),
                  ),
                ],
              ],
              
              if (request.evidenceLinks?.isNotEmpty ?? false) ...[
                const SizedBox(height: 16),
                const Text('Evidence Links:', style: TextStyle(color: FlownetColors.electricBlue, fontWeight: FontWeight.bold)),
                ...request.evidenceLinks!.map((link) => 
                  Text(link, style: const TextStyle(color: FlownetColors.pureWhite))
                ),
              ],
              
              if (request.definitionOfDone?.isNotEmpty ?? false) ...[
                const SizedBox(height: 16),
                const Text('Definition of Done:', style: TextStyle(color: FlownetColors.electricBlue, fontWeight: FontWeight.bold)),
                ...request.definitionOfDone!.map((item) => 
                  Text('• $item', style: const TextStyle(color: FlownetColors.pureWhite))
                ),
              ],
              
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Requested by:', style: TextStyle(color: FlownetColors.coolGray)),
                        Text(request.requestedByName, style: const TextStyle(color: FlownetColors.pureWhite)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Priority:', style: TextStyle(color: FlownetColors.coolGray)),
                        Text(request.priorityDisplay, style: const TextStyle(color: FlownetColors.pureWhite)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Category:', style: TextStyle(color: FlownetColors.coolGray)),
                        Text(request.category, style: const TextStyle(color: FlownetColors.pureWhite)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Status:', style: TextStyle(color: FlownetColors.coolGray)),
                        Text(request.statusDisplay, style: const TextStyle(color: FlownetColors.pureWhite)),
                      ],
                    ),
                  ),
                ],
              ),
              if (request.reviewReason != null) ...[
                const SizedBox(height: 16),
                const Text('Review Reason:', style: TextStyle(color: FlownetColors.coolGray)),
                const SizedBox(height: 8),
                Text(request.reviewReason!, style: const TextStyle(color: FlownetColors.pureWhite)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: FlownetColors.coolGray)),
          ),
          if (request.isPending) ...[
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _rejectRequest(request);
              },
              style: ElevatedButton.styleFrom(backgroundColor: FlownetColors.crimsonRed),
              child: const Text('Reject', style: TextStyle(color: FlownetColors.pureWhite)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _approveRequest(request);
              },
              style: ElevatedButton.styleFrom(backgroundColor: FlownetColors.electricBlue),
              child: const Text('Approve', style: TextStyle(color: FlownetColors.pureWhite)),
            ),
          ],
        ],
      ),
    );
  }

  void _previewDeliverable(core.ApprovalRequest request) {
    // Fetch deliverable details from API
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Deliverable: ${request.deliverableTitle ?? 'Unknown Deliverable'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (request.evidenceLinks?.isNotEmpty ?? false)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Evidence:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...request.evidenceLinks!.map((link) => 
                    Text(link, style: const TextStyle(color: Colors.blue))
                  ),
                ],
              ),
            if (request.definitionOfDone?.isNotEmpty ?? false)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Definition of Done:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...request.definitionOfDone!.map((item) => 
                    Text('• $item')
                  ),
                ],
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadApprovalRequests,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: FlownetColors.graphiteGray,
              border: Border(
                bottom: BorderSide(color: FlownetColors.slate, width: 1),
              ),
            ),
            child: Column(
              children: [
                // Search bar
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: const InputDecoration(
                    hintText: 'Search approval requests...',
                    hintStyle: TextStyle(color: FlownetColors.coolGray),
                    prefixIcon: Icon(Icons.search, color: FlownetColors.coolGray),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: FlownetColors.charcoalBlack,
                  ),
                  style: const TextStyle(color: FlownetColors.pureWhite),
                ),
                const SizedBox(height: 16),
                // Filter row
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedStatus,
                        onChanged: (value) {
                          setState(() => _selectedStatus = value!);
                          _loadApprovalRequests();
                        },
                        dropdownColor: FlownetColors.graphiteGray,
                        style: const TextStyle(color: FlownetColors.pureWhite),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Status')),
                          DropdownMenuItem(value: 'pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'approved', child: Text('Approved')),
                          DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                          DropdownMenuItem(value: 'deliverable', child: Text('Deliverables')),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedPriority,
                        onChanged: (value) {
                          setState(() => _selectedPriority = value!);
                          _loadApprovalRequests();
                        },
                        dropdownColor: FlownetColors.graphiteGray,
                        style: const TextStyle(color: FlownetColors.pureWhite),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Priority')),
                          DropdownMenuItem(value: 'low', child: Text('Low')),
                          DropdownMenuItem(value: 'medium', child: Text('Medium')),
                          DropdownMenuItem(value: 'high', child: Text('High')),
                          DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedCategory,
                        onChanged: (value) {
                          setState(() => _selectedCategory = value!);
                          _loadApprovalRequests();
                        },
                        dropdownColor: FlownetColors.graphiteGray,
                        style: const TextStyle(color: FlownetColors.pureWhite),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Categories')),
                          DropdownMenuItem(value: 'Security', child: Text('Security')),
                          DropdownMenuItem(value: 'Database', child: Text('Database')),
                          DropdownMenuItem(value: 'Documentation', child: Text('Documentation')),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedSprintId,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedSprintId = value;
                            if (_selectedDeliverableId != 'all' && !_deliverableMatchesSprintById(_selectedDeliverableId, _selectedSprintId)) {
                              _selectedDeliverableId = 'all';
                            }
                          });
                        },
                        dropdownColor: FlownetColors.graphiteGray,
                        style: const TextStyle(color: FlownetColors.pureWhite),
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('All Sprints')),
                          ..._sprints.map((s) {
                            final id = (s['id'] ?? s['sprint_id'] ?? s['sprintId']).toString();
                            final name = (s['name'] ?? s['title'] ?? 'Unnamed Sprint').toString();
                            return DropdownMenuItem(value: id, child: Text(name));
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedDeliverableId,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedDeliverableId = value);
                          _loadApprovalRequests();
                        },
                        dropdownColor: FlownetColors.graphiteGray,
                        style: const TextStyle(color: FlownetColors.pureWhite),
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('All Deliverables')),
                          ..._visibleDeliverables.map((d) {
                            if (d is Map<String, dynamic>) {
                              final id = (d['id'] ?? '').toString();
                              final title = (d['title'] ?? 'Untitled').toString();
                              return DropdownMenuItem(value: id, child: Text(title));
                            }
                            try {
                              final id = d.id.toString();
                              final title = (d.title ?? 'Untitled').toString();
                              return DropdownMenuItem(value: id, child: Text(title));
                            } catch (_) {
                              final text = d.toString();
                              return DropdownMenuItem(value: text, child: Text(text));
                            }
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Requests list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(FlownetColors.crimsonRed),
                    ),
                  )
                : _filteredRequests.isEmpty
                    ? const Center(
                        child: Text(
                          'No approval requests found',
                          style: TextStyle(color: FlownetColors.coolGray, fontSize: 18),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredRequests.length,
                        itemBuilder: (context, index) {
                          final request = _filteredRequests[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            color: FlownetColors.graphiteGray,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Row(
                                children: [
                                  if (request.deliverableId != null) 
                                    const Icon(Icons.description, color: FlownetColors.electricBlue, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      request.title,
                                      style: const TextStyle(
                                        color: FlownetColors.pureWhite,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Text(
                                    'Requested by: ${request.requestedByName}',
                                    style: const TextStyle(color: FlownetColors.coolGray),
                                  ),
if (_getSprintName(request).isNotEmpty)
                                    Text(
                                      'Sprint: ${_getSprintName(request)}',
                                      style: const TextStyle(color: FlownetColors.electricBlue, fontWeight: FontWeight.bold),
                                    ),
                                  Text(
                                    'Date: ${_formatSaDate(request.requestedAt)}',
                                    style: const TextStyle(color: FlownetColors.coolGray),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    request.description,
                                    style: const TextStyle(color: FlownetColors.pureWhite),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Status chip
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: request.isPending
                                          ? FlownetColors.amberOrange
                                          : request.isApproved
                                              ? FlownetColors.electricBlue
                                              : FlownetColors.crimsonRed,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      request.statusDisplay,
                                      style: const TextStyle(
                                        color: FlownetColors.pureWhite,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Action buttons
                                  if (request.isPending) ...[
                                    IconButton(
                                      icon: const Icon(Icons.check, color: FlownetColors.electricBlue),
                                      onPressed: () => _approveRequest(request),
                                      tooltip: 'Approve',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: FlownetColors.crimsonRed),
                                      onPressed: () => _rejectRequest(request),
                                      tooltip: 'Reject',
                                    ),
                                  ],
                                  if (request.deliverableId != null) ...[
                                    IconButton(
                                      icon: const Icon(Icons.preview, color: FlownetColors.coolGray),
                                      onPressed: () => _previewDeliverable(request),
                                      tooltip: 'Preview Deliverable',
                                    ),
                                  ],
                                  IconButton(
                                    icon: const Icon(Icons.visibility, color: FlownetColors.electricBlue),
                                    onPressed: () => _openAssociatedReport(request),
                                    tooltip: 'View Associated Report',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.info, color: FlownetColors.coolGray),
                                    onPressed: () => _showRequestDetails(request),
                                    tooltip: 'View Details',
                                  ),
                                ],
                              ),
                              onTap: () => _openAssociatedReport(request),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

