import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/client_approval_request.dart';
import '../providers/service_providers.dart';

class ClientApprovalState {
  final List<ClientApprovalRequest> approvalRequests;
  final bool isLoading;
  final String? error;

  ClientApprovalState({
    required this.approvalRequests,
    this.isLoading = false,
    this.error,
  });

  ClientApprovalState copyWith({
    List<ClientApprovalRequest>? approvalRequests,
    bool? isLoading,
    String? error,
  }) {
    return ClientApprovalState(
      approvalRequests: approvalRequests ?? this.approvalRequests,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class ClientApprovalNotifier extends Notifier<ClientApprovalState> {
  @override
  ClientApprovalState build() {
    return ClientApprovalState(approvalRequests: []);
  }

  Future<void> loadApprovalRequests() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final backend = ref.read(backendApiServiceProvider);
      final response = await backend.getApprovalRequests(page: 1, limit: 50);
      final List<ClientApprovalRequest> requests = [];
      final items = response.data != null
          ? (response.data!['data'] ?? response.data!['approvals'] ?? response.data!['items'] ?? [])
          : [];
      for (final item in items) {
        final parsed = {
          'id': (item['id']?.toString() ?? ''),
          'deliverableId': item['deliverable_id']?.toString() ?? item['deliverableId'],
          'deliverableTitle': item['deliverable_title'] ?? item['deliverableTitle'] ?? '',
          'clientId': item['client_id']?.toString() ?? item['clientId'] ?? '',
          'clientName': item['client_name'] ?? item['clientName'] ?? '',
          'deliveryManagerId': item['requested_by']?.toString() ?? item['deliveryManagerId'] ?? '',
          'deliveryManagerName': item['requested_by_name'] ?? item['deliveryManagerName'] ?? '',
          'requestedAt': item['requested_at'] ?? item['requestedAt'] ?? DateTime.now().toIso8601String(),
          'approvedAt': item['approved_at'] ?? item['approvedAt'],
          'rejectedAt': item['rejected_at'] ?? item['rejectedAt'],
          'status': item['status'] ?? 'pending',
          'comments': item['comments'],
          'reminderSentAt': item['reminder_sent_at'] ?? item['reminderSentAt'] ?? [],
          'dueDate': item['due_date'] ?? item['dueDate'],
        };
        try {
          requests.add(ClientApprovalRequest.fromJson(parsed));
        } catch (_) {}
      }
      state = state.copyWith(approvalRequests: requests, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load approval requests: $e',
      );
    }
  }


  Future<void> sendForApproval({
    required String deliverableId,
    required String deliverableTitle,
    required String clientId,
    required String clientName,
    DateTime? dueDate,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final backend = ref.read(backendApiServiceProvider);
      final auth = ref.read(authServiceProvider);
      final me = await auth.getCurrentUser();
      final requesterId = me?.id ?? '';
      final requestData = {
        'deliverable_id': deliverableId,
        'deliverable_title': deliverableTitle,
        'client_id': clientId,
        'client_name': clientName,
        'requested_by': requesterId,
        if (dueDate != null) 'due_date': dueDate.toIso8601String(),
      };
      final response = await backend.createApprovalRequest(requestData);
      final newId = response.data != null
          ? (response.data!['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString())
          : DateTime.now().millisecondsSinceEpoch.toString();
      final newRequest = ClientApprovalRequest(
        id: newId,
        deliverableId: deliverableId,
        deliverableTitle: deliverableTitle,
        clientId: clientId,
        clientName: clientName,
        deliveryManagerId: '',
        deliveryManagerName: '',
        requestedAt: DateTime.now(),
        status: ClientApprovalStatus.pending,
        dueDate: dueDate,
      );
      state = state.copyWith(
        approvalRequests: [...state.approvalRequests, newRequest],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to send for approval: $e',
      );
    }
  }

  Future<void> approveRequest(String requestId, {String? comments}) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final backend = ref.read(backendApiServiceProvider);
      await backend.approveRequest(requestId, {
        if (comments != null) 'comments': comments,
      });
      final updatedRequests = state.approvalRequests.map((request) {
        if (request.id == requestId) {
          return request.copyWith(
            status: ClientApprovalStatus.approved,
            approvedAt: DateTime.now(),
            comments: comments,
          );
        }
        return request;
      }).toList();
      
      state = state.copyWith(
        approvalRequests: updatedRequests,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to approve request: $e',
      );
    }
  }

  Future<void> rejectRequest(String requestId, {required String comments}) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final backend = ref.read(backendApiServiceProvider);
      await backend.rejectRequest(requestId, {
        'comments': comments,
      });
      final updatedRequests = state.approvalRequests.map((request) {
        if (request.id == requestId) {
          return request.copyWith(
            status: ClientApprovalStatus.rejected,
            rejectedAt: DateTime.now(),
            comments: comments,
          );
        }
        return request;
      }).toList();
      
      state = state.copyWith(
        approvalRequests: updatedRequests,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to reject request: $e',
      );
    }
  }

  Future<void> sendReminder(String requestId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final backend = ref.read(backendApiServiceProvider);
      await backend.sendReminder(requestId);
      final updatedRequests = state.approvalRequests.map((request) {
        if (request.id == requestId) {
          final updatedReminders = [...request.reminderSentAt, DateTime.now()];
          return request.copyWith(
            status: ClientApprovalStatus.reminderSent,
            reminderSentAt: updatedReminders,
          );
        }
        return request;
      }).toList();
      
      state = state.copyWith(
        approvalRequests: updatedRequests,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to send reminder: $e',
      );
    }
  }

  List<ClientApprovalRequest> getPendingApprovals() {
    return state.approvalRequests
        .where((request) => request.status == ClientApprovalStatus.pending)
        .toList();
  }

  List<ClientApprovalRequest> getOverdueApprovals() {
    return state.approvalRequests
        .where((request) => request.status == ClientApprovalStatus.pending && 
            request.dueDate != null && 
            request.dueDate!.isBefore(DateTime.now()),
        )
        .toList();
  }

  List<ClientApprovalRequest> getApprovalsNeedingReminder() {
    return state.approvalRequests
        .where((request) => request.status == ClientApprovalStatus.pending && 
            request.dueDate != null && 
            request.dueDate!.difference(DateTime.now()).inDays <= 1,
        )
        .toList();
  }
}

final clientApprovalProvider = NotifierProvider<ClientApprovalNotifier, ClientApprovalState>(
  () => ClientApprovalNotifier(),
);
