import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../models/approval_request.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../config/environment.dart';
import 'realtime_service.dart';

class ApprovalService {
  final AuthService _authService;
  final ApiClient _apiClient = ApiClient();
  final String _baseUrl = Environment.apiBaseUrl;
  RealtimeService? _realtime;
  StreamController<List<ApprovalRequest>>? _requestsController;

  ApprovalService(this._authService);

  Stream<List<ApprovalRequest>> get approvalRequestsStream {
    _requestsController ??= StreamController<List<ApprovalRequest>>.broadcast();
    return _requestsController!.stream;
  }

  Future<void> initRealtime() async {
    try {
      await _authService.initialize();
      final token = _authService.accessToken;
      if (token == null || token.isEmpty) {
        return;
      }
      _realtime = RealtimeService();
      await _realtime!.initialize(authToken: token);
      _realtime!.on('approval_created', (_) => _refreshStream());
      _realtime!.on('approval_updated', (_) => _refreshStream());
      _realtime!.on('report_submitted', (_) => _refreshStream());
      _realtime!.on('report_approved', (_) => _refreshStream());
      _realtime!.on('report_change_requested', (_) => _refreshStream());
      await _refreshStream();
    } catch (_) {}
  }

  void disposeRealtime() {
    try {
      _realtime?.offAll('approval_created');
      _realtime?.offAll('approval_updated');
      _realtime?.offAll('report_submitted');
      _realtime?.offAll('report_approved');
      _realtime?.offAll('report_change_requested');
    } catch (_) {}
    try {
      _requestsController?.close();
    } catch (_) {}
    _requestsController = null;
    _realtime = null;
  }

  Future<void> _refreshStream() async {
    try {
      final resp = await getApprovalRequests();
      if (resp.isSuccess) {
        final list = (resp.data?['requests'] as List?)?.cast<ApprovalRequest>() ?? <ApprovalRequest>[];
        _requestsController ??= StreamController<List<ApprovalRequest>>.broadcast();
        _requestsController!.add(list);
      }
    } catch (_) {}
  }

  // Get all approval requests
  Future<ApiResponse> getApprovalRequests({
    String? status,
    String? priority,
    String? category,
    String? deliverableId,
  }) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('No authentication token available');
      }

      final queryParams = {
        if (status != null) 'status': status,
        if (priority != null) 'priority': priority,
        if (category != null) 'category': category,
        if (deliverableId != null && deliverableId.isNotEmpty) 'deliverable_id': deliverableId,
      };

      debugPrint('🔍 Fetching approval requests with params: $queryParams');
      final response = await _apiClient.get('/approvals', queryParams: queryParams);

      debugPrint('📡 Approval requests response: ${response.statusCode} - ${response.isSuccess}');
      
      if (response.isSuccess) {
        final data = response.data;
        final list = data is List ? data : (data['data'] as List? ?? []);
        final requests = list.map((e) {
          final deliverable = e['deliverable'] as Map<String, dynamic>? ?? {};
          final requester = e['requester'] as Map<String, dynamic>? ?? {};
          final approver = e['approver'] as Map<String, dynamic>? ?? {};
          final requestedByName = e['requested_by_name']?.toString().trim();
          final reviewedByName = e['reviewed_by_name']?.toString().trim();
          return ApprovalRequest(
            id: e['id']?.toString() ?? '',
            title: e['title']?.toString() ?? deliverable['title']?.toString() ?? 'Approval Request',
            description: e['description']?.toString() ?? e['comments']?.toString() ?? '',
            requestedBy: e['requested_by']?.toString() ?? requester['id']?.toString() ?? '',
            requestedByName: (requestedByName != null && requestedByName.isNotEmpty)
                ? requestedByName
                : ([requester['first_name'], requester['last_name']].whereType<String>().where((s) => s.isNotEmpty).join(' ').trim().isNotEmpty
                    ? [requester['first_name'], requester['last_name']].whereType<String>().join(' ').trim()
                    : (requester['email']?.toString() ?? 'Unknown')),
            requestedAt: _parseDateTime(e['requested_at']) ?? DateTime.now(),
            status: _parseStatus(e['status']?.toString() ?? 'pending'),
            reviewedBy: e['reviewed_by']?.toString() ?? e['approved_by']?.toString() ?? e['rejected_by']?.toString() ?? approver['id']?.toString(),
            reviewedByName: (reviewedByName != null && reviewedByName.isNotEmpty)
                ? reviewedByName
                : ([approver['first_name'], approver['last_name']].whereType<String>().where((s) => s.isNotEmpty).join(' ').trim().isNotEmpty
                    ? [approver['first_name'], approver['last_name']].whereType<String>().join(' ').trim()
                    : (approver['email']?.toString())),
            reviewedAt: _parseDateTime(e['reviewed_at'] ?? e['approved_at'] ?? e['rejected_at']),
            reviewReason: e['review_reason']?.toString() ?? e['comments']?.toString(),
            priority: e['priority']?.toString() ?? 'medium',
            category: e['category']?.toString() ?? '',
            deliverableId: deliverable['id']?.toString() ?? e['deliverable_id']?.toString(),
          );
        }).toList();
        return ApiResponse.success({'requests': requests}, 200);
      } else {
        return ApiResponse.error('Failed to fetch approval requests');
      }
    } catch (e) {
      return ApiResponse.error('Error fetching approval requests: $e');
    }
  }

  // Create a new approval request
  Future<ApiResponse> createApprovalRequest({
    required String deliverableId,
    required String requestedBy,
    String? comments,
    String? category,
    String priority = 'medium',
  }) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('No authentication token available');
      }
      final uri = Uri.parse('$_baseUrl/approvals');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'deliverable_id': deliverableId,
          'requested_by': requestedBy,
          if (comments != null) 'comments': comments,
          if (category != null) 'category': category,
          if (priority.isNotEmpty) 'priority': priority,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final e = data['data'] ?? data;
        final deliverable = e['deliverable'] as Map<String, dynamic>? ?? {};
        final requester = e['requester'] as Map<String, dynamic>? ?? {};
        final approver = e['approver'] as Map<String, dynamic>? ?? {};
        final request = ApprovalRequest(
          id: e['id']?.toString() ?? '',
          title: deliverable['title']?.toString() ?? 'Approval Request',
          description: e['comments']?.toString() ?? '',
          requestedBy: e['requested_by']?.toString() ?? requester['id']?.toString() ?? requestedBy,
          requestedByName: [requester['first_name'], requester['last_name']].whereType<String>().where((s) => s.isNotEmpty).join(' ').trim().isNotEmpty
              ? [requester['first_name'], requester['last_name']].whereType<String>().join(' ').trim()
              : (requester['email']?.toString() ?? requestedBy),
          requestedAt: _parseDateTime(e['requested_at']) ?? DateTime.now(),
          status: _parseStatus(e['status']?.toString() ?? 'pending'),
          reviewedBy: e['approved_by']?.toString() ?? e['rejected_by']?.toString() ?? approver['id']?.toString(),
          reviewedByName: [approver['first_name'], approver['last_name']].whereType<String>().where((s) => s.isNotEmpty).join(' ').trim().isNotEmpty
              ? [approver['first_name'], approver['last_name']].whereType<String>().join(' ').trim()
              : (approver['email']?.toString()),
          reviewedAt: _parseDateTime(e['approved_at'] ?? e['rejected_at']),
          reviewReason: e['comments']?.toString(),
          priority: e['priority']?.toString() ?? priority,
          category: e['category']?.toString() ?? (category ?? ''),
          deliverableId: deliverable['id']?.toString() ?? e['deliverable_id']?.toString() ?? deliverableId,
        );
        return ApiResponse.success({'request': request}, response.statusCode);
      } else {
        return ApiResponse.error('Failed to create approval request: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResponse.error('Error creating approval request: $e');
    }
  }

  // Get specific approval request
  Future<ApiResponse> getApprovalRequest(String requestId) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('No authentication token available');
      }

      final uri = Uri.parse('$_baseUrl/approvals/$requestId');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true || data['id'] != null) {
          final e = data['data'] ?? data;
          final deliverable = e['deliverable'] as Map<String, dynamic>? ?? {};
          final requester = e['requester'] as Map<String, dynamic>? ?? {};
          final approver = e['approver'] as Map<String, dynamic>? ?? {};
          final request = ApprovalRequest(
            id: e['id']?.toString() ?? '',
            title: deliverable['title']?.toString() ?? 'Approval Request',
            description: e['comments']?.toString() ?? '',
            requestedBy: e['requested_by']?.toString() ?? requester['id']?.toString() ?? '',
            requestedByName: [requester['first_name'], requester['last_name']].whereType<String>().where((s) => s.isNotEmpty).join(' ').trim().isNotEmpty
                ? [requester['first_name'], requester['last_name']].whereType<String>().join(' ').trim()
                : (requester['email']?.toString() ?? 'Unknown'),
            requestedAt: _parseDateTime(e['requested_at']) ?? DateTime.now(),
            status: _parseStatus(e['status']?.toString() ?? 'pending'),
            reviewedBy: e['approved_by']?.toString() ?? e['rejected_by']?.toString() ?? approver['id']?.toString(),
            reviewedByName: [approver['first_name'], approver['last_name']].whereType<String>().where((s) => s.isNotEmpty).join(' ').trim().isNotEmpty
                ? [approver['first_name'], approver['last_name']].whereType<String>().join(' ').trim()
                : (approver['email']?.toString()),
            reviewedAt: _parseDateTime(e['approved_at'] ?? e['rejected_at']),
            reviewReason: e['comments']?.toString(),
            priority: e['priority']?.toString() ?? 'medium',
            category: e['category']?.toString() ?? '',
            deliverableId: deliverable['id']?.toString() ?? e['deliverable_id']?.toString(),
          );
          return ApiResponse.success({'request': request}, 200);
        } else {
          return ApiResponse.error(data['error'] ?? 'Failed to fetch approval request');
        }
      } else {
        return ApiResponse.error('Failed to fetch approval request');
      }
    } catch (e) {
      return ApiResponse.error('Error fetching approval request: $e');
    }
  }

  // Create a new approval request (e.g. when a deliverable/report is submitted)
  Future<ApiResponse> createGeneralApprovalRequest({
    required String title,
    required String description,
    String priority = 'medium',
    String category = 'general',
    String? deliverableId,
    List<String>? evidenceLinks,
    List<String>? definitionOfDone,
  }) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('No authentication token available');
      }
      if (deliverableId == null || deliverableId.isEmpty) {
        return ApiResponse.error('Deliverable ID is required');
      }
      final requestedBy = _authService.currentUser?.id.toString();
      if (requestedBy == null || requestedBy.isEmpty) {
        return ApiResponse.error('Requester ID is required');
      }

      final response = await _apiClient.post('/approvals', body: {
        'deliverable_id': deliverableId,
        'requested_by': requestedBy,
        'comments': description,
        'priority': priority,
        'category': category,
        if (evidenceLinks != null) 'evidence_links': evidenceLinks,
        if (definitionOfDone != null) 'definition_of_done': definitionOfDone,
      });

      if (response.isSuccess && response.data != null) {
        final request = ApprovalRequest.fromJson(response.data as Map<String, dynamic>);
        return ApiResponse.success({'request': request}, response.statusCode);
      }
      return ApiResponse.error(response.error ?? 'Failed to create approval request', response.statusCode);
    } catch (e) {
      return ApiResponse.error('Error creating approval request: $e');
    }
  }

  // Approve an approval request
  Future<ApiResponse> approveRequest(String requestId, String reason) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('No authentication token available');
      }

      final approvedBy = _authService.currentUser?.id.toString() ?? '';
      final response = await _apiClient.put('/approvals/$requestId/approve', body: {
        'comments': reason,
        'approved_by': approvedBy,
      });

      if (response.isSuccess) {
        return response;
      } else {
        return response;
      }
    } catch (e) {
      return ApiResponse.error('Error approving request: $e');
    }
  }

  // Reject an approval request
  Future<ApiResponse> rejectRequest(String requestId, String reason) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('No authentication token available');
      }

      final approvedBy = _authService.currentUser?.id.toString() ?? '';
      final response = await _apiClient.put('/approvals/$requestId/reject', body: {
        'comments': reason,
        'approved_by': approvedBy,
      });

      if (response.isSuccess) {
        return response;
      } else {
        return response;
      }
    } catch (e) {
      return ApiResponse.error('Error rejecting request: $e');
    }
  }
DateTime? _parseDateTime(dynamic input) {
    if (input == null) return null;
    if (input is DateTime) return input;
    if (input is String) {
      final s = input.trim();
      if (s.isEmpty) return null;
      try {
        return DateTime.parse(s);
      } catch (_) {
        final n = int.tryParse(s);
        if (n == null) return null;
        if (n > 100000000000) {
          return DateTime.fromMillisecondsSinceEpoch(n);
        } else if (n > 1000000000) {
          return DateTime.fromMillisecondsSinceEpoch(n * 1000);
        } else {
          return null;
        }
      }
    }
    if (input is num) {
      final n = input.toInt();
      if (n > 100000000000) {
        return DateTime.fromMillisecondsSinceEpoch(n);
      } else if (n > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(n * 1000);
      }
    }
    return null;
  }

  String _parseStatus(String status) {
    final s = status.toLowerCase().trim();
    switch (s) {
      case 'pending':
      case 'in_review':
      case 'awaiting':
      case 'waiting':
        return 'pending';
      case 'approved':
      case 'accept':
      case 'accepted':
      case 'confirm':
      case 'confirmed':
        return 'approved';
      case 'rejected':
      case 'reject':
      case 'denied':
      case 'deny':
        return 'rejected';
      default:
        return 'pending';
    }
  }
}
