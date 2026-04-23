import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/approval_request.dart';
import '../services/approval_service.dart';
import '../services/auth_service.dart';
import '../theme/flownet_theme.dart';
import '../widgets/flownet_logo.dart';

class ApprovalsScreen extends ConsumerStatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  ConsumerState<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends ConsumerState<ApprovalsScreen> {
  final ApprovalService _approvalService = ApprovalService(AuthService());
  List<ApprovalRequest> _approvalRequests = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'all';
  Timer? _refreshTimer;
  StreamSubscription<List<ApprovalRequest>>? _approvalSubscription;

  @override
  void initState() {
    super.initState();
    _approvalService.initRealtime();
    _approvalSubscription = _approvalService.approvalRequestsStream.listen((requests) {
      setState(() {
        _approvalRequests = requests;
      });
    });
    _loadApprovalRequests();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadApprovalRequests();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _approvalSubscription?.cancel();
    _approvalService.disposeRealtime();
    super.dispose();
  }

  Future<void> _loadApprovalRequests() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await _approvalService.getApprovalRequests();
      
      if (response.isSuccess) {
        setState(() {
          _approvalRequests = response.data!['requests'].cast<ApprovalRequest>();
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

  List<ApprovalRequest> get _filteredRequests {
    return _approvalRequests.where((request) {
      final matchesSearch = _searchQuery.isEmpty ||
          request.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          request.description.toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesStatus = _selectedStatus == 'all' || request.status == _selectedStatus;
      
      return matchesSearch && matchesStatus;
    }).toList();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: FlownetColors.crimsonRed,
      ),
    );
  }

  void _showRequestDetails(ApprovalRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FlownetColors.graphiteGray,
        title: Text(
          request.title,
          style: const TextStyle(color: FlownetColors.pureWhite),
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Description:',
                  style: TextStyle(
                    color: FlownetColors.electricBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  request.description,
                  style: const TextStyle(color: FlownetColors.pureWhite),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Requested by:',
                            style: TextStyle(color: FlownetColors.coolGray),
                          ),
                          Text(
                            request.requestedByName,
                            style: const TextStyle(color: FlownetColors.pureWhite),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Status:',
                            style: TextStyle(color: FlownetColors.coolGray),
                          ),
                          Text(
                            request.statusDisplay,
                            style: const TextStyle(color: FlownetColors.pureWhite),
                          ),
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
                          const Text(
                            'Priority:',
                            style: TextStyle(color: FlownetColors.coolGray),
                          ),
                          Text(
                            request.priorityDisplay,
                            style: const TextStyle(color: FlownetColors.pureWhite),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Category:',
                            style: TextStyle(color: FlownetColors.coolGray),
                          ),
                          Text(
                            request.category,
                            style: const TextStyle(color: FlownetColors.pureWhite),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (request.reviewReason != null && request.reviewReason!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Review Reason:',
                    style: TextStyle(color: FlownetColors.coolGray),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    request.reviewReason!,
                    style: const TextStyle(color: FlownetColors.pureWhite),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: FlownetColors.coolGray),
            ),
          ),
          if (request.isPending) ...[
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _rejectRequest(request);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: FlownetColors.crimsonRed,
              ),
              child: const Text(
                'Reject',
                style: TextStyle(color: FlownetColors.pureWhite),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _approveRequest(request);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: FlownetColors.electricBlue,
              ),
              child: const Text(
                'Approve',
                style: TextStyle(color: FlownetColors.pureWhite),
              ),
            ),
          ],
        ],
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

  Future<void> _approveRequest(ApprovalRequest request) async {
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

  Future<void> _rejectRequest(ApprovalRequest request) async {
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
                        value: _selectedStatus,
                        onChanged: (value) => setState(() => _selectedStatus = value!),
                        dropdownColor: FlownetColors.graphiteGray,
                        style: const TextStyle(color: FlownetColors.pureWhite),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Status')),
                          DropdownMenuItem(value: 'pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'approved', child: Text('Approved')),
                          DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Approval requests list
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
                              title: Text(
                                request.title,
                                style: const TextStyle(
                                  color: FlownetColors.pureWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Text(
                                    'Requested by: ${request.requestedByName}',
                                    style: const TextStyle(color: FlownetColors.coolGray),
                                  ),
                                  Text(
                                    'Date: ${request.requestedAt.day}/${request.requestedAt.month}/${request.requestedAt.year}',
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
                                ],
                              ),
                              onTap: () => _showRequestDetails(request),
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
