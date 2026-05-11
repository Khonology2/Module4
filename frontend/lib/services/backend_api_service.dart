import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'package:khono/models/user.dart';
import 'package:khono/models/user_role.dart';
import 'package:khono/models/deliverable.dart';
import 'package:khono/models/sprint_metrics.dart';
import 'package:khono/models/sign_off_report.dart';
import 'package:khono/config/environment.dart';

class BackendApiService {
  static final BackendApiService _instance = BackendApiService._internal();
  factory BackendApiService() => _instance;
  BackendApiService._internal();

  final ApiClient _apiClient = ApiClient();

  // Getters
  String? get accessToken => _apiClient.accessToken;

  // Initialize the service
  Future<void> initialize() async {
    await _apiClient.initialize();
    debugPrint('Backend API Service initialized');
  }

  // Authentication endpoints
  Future<ApiResponse> signIn(String email, String password) async {
    return await _apiClient.login(email, password);
  }

  Future<ApiResponse> signUp(
      String email, String password, String name, UserRole role) async {
    // Parse the full name into firstName and lastName for the backend
    final nameParts = name.trim().split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    // Use different endpoints based on environment
    final endpoint =
        Environment.isRenderDeployed ? '/auth/signup' : '/auth/register';

    debugPrint(
        '🔍 Environment.isRenderDeployed: ${Environment.isRenderDeployed}');
    debugPrint('🔍 Using endpoint: $endpoint');
    debugPrint('🔍 Signing up with email: $email');

    final response = await _apiClient.post(endpoint, body: {
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      'role': role.name,
    });

    debugPrint(
        '🔍 Signup response: ${response.statusCode} - ${response.error ?? "Success"}');
    return response;
  }

  Future<ApiResponse> signOut() async {
    return await _apiClient.logout();
  }

  Future<ApiResponse> getCurrentUser() async {
    return await _apiClient.getCurrentUser();
  }

  Future<ApiResponse> updateProfile(Map<String, dynamic> updates) async {
    final me = await _apiClient.getCurrentUser();
    if (!me.isSuccess || me.data == null) {
      return ApiResponse.error('Failed to load current user');
    }
    final user = me.data['user'] ?? me.data;
    final id = user['id']?.toString();
    if (id == null || id.isEmpty) {
      return ApiResponse.error('Missing user id');
    }
    return await _apiClient.put('/profile/$id', body: updates);
  }

  Future<ApiResponse> changePassword(
      String currentPassword, String newPassword) async {
    return await _apiClient.changePassword(currentPassword, newPassword);
  }

  Future<ApiResponse> forgotPassword(String email) async {
    return await _apiClient.forgotPassword(email);
  }

  Future<ApiResponse> resetPassword(String token, String newPassword) async {
    return await _apiClient.resetPassword(token, newPassword);
  }

  // Token management
  Future<void> saveTokens(
      String accessToken, String refreshToken, DateTime expiry) async {
    await _apiClient.saveTokens(accessToken, refreshToken, expiry);
  }

  // User management endpoints
  Future<ApiResponse> getUsers(
      {int page = 1, int limit = 20, String? search}) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    return await _apiClient.get('/users', queryParams: queryParams);
  }

  Future<ApiResponse> getUser(String userId) async {
    return await _apiClient.get('/users/$userId');
  }

  Future<ApiResponse> updateUser(
      String userId, Map<String, dynamic> updates) async {
    return await _apiClient.put('/users/$userId', body: updates);
  }

  Future<ApiResponse> deleteUser(String userId) async {
    return await _apiClient.delete('/users/$userId');
  }

  Future<ApiResponse> updateUserRole(String userId, UserRole newRole) async {
    return await _apiClient
        .put('/users/$userId/role', body: {'role': newRole.name});
  }

  Future<ApiResponse> createUser({
    required String email,
    required String name,
    required String role,
    required String password,
  }) async {
    return await _apiClient.post(
      '/users',
      body: {
        'email': email,
        'name': name,
        'role': role,
        'password': password,
      },
    );
  }

  // Deliverable endpoints - Updated for integration
  Future<ApiResponse> getDeliverables(
      {int page = 1, int limit = 20, String? status, String? search}) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    return await _apiClient.get('/deliverables', queryParams: queryParams);
  }

  Future<ApiResponse> getDeliverable(String deliverableId) async {
    return await _apiClient.get('/deliverables/$deliverableId');
  }

  Future<ApiResponse> createDeliverable(
      Map<String, dynamic> deliverableData) async {
    return await _apiClient.post('/deliverables', body: deliverableData);
  }

  Future<ApiResponse> updateDeliverable(
      String deliverableId, Map<String, dynamic> updates) async {
    return await _apiClient.put('/deliverables/$deliverableId', body: updates);
  }

  Future<ApiResponse> updateDeliverableStatus(
      String deliverableId, String status) async {
    return await _apiClient.put('/deliverables/$deliverableId/updateStatus',
        body: {'status': status});
  }

  Future<ApiResponse> deleteDeliverable(String deliverableId) async {
    return await _apiClient.delete('/deliverables/$deliverableId');
  }

  Future<ApiResponse> submitDeliverable(String deliverableId) async {
    return await _apiClient.post('/deliverables/$deliverableId/submit');
  }

  Future<ApiResponse> approveDeliverable(
      String deliverableId, String? comment) async {
    return await _apiClient.post(
      '/deliverables/$deliverableId/approve',
      body: {
        'comment': comment,
      },
    );
  }

  Future<ApiResponse> requestChanges(
      String deliverableId, String changeRequest) async {
    return await _apiClient.post(
      '/deliverables/$deliverableId/request-changes',
      body: {
        'change_request': changeRequest,
      },
    );
  }

  Future<ApiResponse> uploadDeliverableArtifact(
    String deliverableId,
    List<int> fileBytes,
    String filename, {
    String? title,
    String? description,
  }) async {
    final fields = <String, String>{};
    if (title != null) fields['title'] = title;
    if (description != null) fields['description'] = description;

    return await _apiClient.uploadFileBytes(
      '/deliverables/$deliverableId/artifacts',
      fileBytes: fileBytes,
      filename: filename,
      fields: fields,
    );
  }

  // Sprint endpoints
  Future<ApiResponse> getSprints(
      {int page = 1, int limit = 20, String? status}) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }
    return await _apiClient.get('/sprints', queryParams: queryParams);
  }

  Future<ApiResponse> getSprint(String sprintId) async {
    return await _apiClient.get('/sprints/$sprintId');
  }

  Future<ApiResponse> createSprint(Map<String, dynamic> sprintData) async {
    return await _apiClient.post('/sprints', body: sprintData);
  }

  Future<ApiResponse> updateSprint(
      String sprintId, Map<String, dynamic> updates) async {
    return await _apiClient.put('/sprints/$sprintId', body: updates);
  }

  Future<ApiResponse> deleteSprint(String sprintId) async {
    return await _apiClient.delete('/sprints/$sprintId');
  }

  Future<ApiResponse> updateSprintStatus(
      String sprintId, Map<String, dynamic> updates) async {
    return await _apiClient.put('/sprints/$sprintId/status', body: updates);
  }

  Future<ApiResponse> runDiagnostics() async {
    return await _apiClient.post('/diagnostics/run');
  }

  // Sprint metrics endpoints
  Future<ApiResponse> getSprintMetrics(String sprintId) async {
    return await _apiClient.get('/sprints/$sprintId/metrics');
  }

  Future<ApiResponse> createSprintMetrics(
      String sprintId, Map<String, dynamic> metricsData) async {
    return await _apiClient.post('/sprints/$sprintId/metrics',
        body: metricsData);
  }

  Future<ApiResponse> updateSprintMetrics(
      String sprintId, Map<String, dynamic> updates) async {
    return await _apiClient.put('/sprints/$sprintId/metrics', body: updates);
  }

  // Sign-off report endpoints
  Future<ApiResponse> getSignOffReports(
      {int page = 1,
      int limit = 20,
      String? status,
      String? search,
      String? deliverableId}) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (deliverableId != null && deliverableId.isNotEmpty) {
      queryParams['deliverableId'] = deliverableId;
    }
    final resp =
        await _apiClient.get('/sign-off-reports', queryParams: queryParams);
    if (resp.isSuccess && resp.data != null) {
      try {
        final raw = resp.data;
        final List<dynamic> items = raw is List
            ? raw
            : (raw['data'] ?? raw['reports'] ?? raw['items'] ?? []);
        await _saveCachedReports(items);
      } catch (_) {}
    }
    return resp;
  }

  Future<ApiResponse> getSignOffReport(String reportId) async {
    return await _apiClient.get('/sign-off-reports/$reportId');
  }

  Future<ApiResponse> createSignOffReport(
      Map<String, dynamic> reportData) async {
    debugPrint('🔵 Creating sign-off report: $reportData');
    final resp = await _apiClient.post('/sign-off-reports', body: reportData);
    if (resp.isSuccess && resp.data != null) {
      try {
        final map = resp.data is Map<String, dynamic>
            ? resp.data as Map<String, dynamic>
            : Map<String, dynamic>.from(resp.data as Map);
        await _prependCachedReport(map);
      } catch (_) {}
    }
    return resp;
  }

  Future<ApiResponse> updateSignOffReport(
      String reportId, Map<String, dynamic> updates) async {
    debugPrint('🔵 Updating sign-off report $reportId: $updates');
    return await _apiClient.put('/sign-off-reports/$reportId', body: updates);
  }

  Future<ApiResponse> deleteSignOffReport(String reportId) async {
    final resp = await _apiClient.delete('/sign-off-reports/$reportId');
    if (resp.isSuccess) {
      try {
        await _removeCachedReport(reportId);
      } catch (_) {}
    }
    return resp;
  }

  Future<ApiResponse> submitSignOffReport(String reportId) async {
    debugPrint('🔵 Submitting sign-off report: $reportId');
    return await _apiClient.post('/sign-off-reports/$reportId/submit');
  }

  Future<ApiResponse> approveSignOffReport(
      String reportId, String? comment, String? digitalSignature,
      {String? reviewToken, String? clientId}) async {
    debugPrint('🔵 Approving/adding feedback to report: $reportId');
    final body = {
      'comment': comment,
      'digitalSignature': digitalSignature,
      if (clientId != null) 'clientId': clientId,
    };
    // If token provided, add it to query or header
    final queryParams = reviewToken != null ? {'token': reviewToken} : null;
    final resp = await _apiClient.post('/sign-off-reports/$reportId/approve',
        body: body, queryParams: queryParams);
    if (resp.isSuccess) {
      try {
        await _updateCachedReportStatus(reportId, 'approved');
      } catch (_) {}
    }
    return resp;
  }

  Future<ApiResponse> requestSignOffChanges(
      String reportId, String changeRequest,
      {String? reviewToken, String? clientId}) async {
    debugPrint('🔵 Requesting changes to report: $reportId');
    final body = {
      'changeRequestDetails': changeRequest,
      if (clientId != null) 'clientId': clientId,
    };
    // If token provided, add it to query
    final queryParams = reviewToken != null ? {'token': reviewToken} : null;
    final resp = await _apiClient.post(
        '/sign-off-reports/$reportId/request-changes',
        body: body,
        queryParams: queryParams);
    if (resp.isSuccess) {
      try {
        await _updateCachedReportStatus(reportId, 'change_requested');
      } catch (_) {}
    }
    return resp;
  }

  /// Create a secure client review link token
  Future<ApiResponse> createClientReviewLink(
      String reportId, String clientEmail,
      {int? expiresInSeconds}) async {
    debugPrint('🔵 Creating client review link for report: $reportId');
    return await _apiClient
        .post('/sign-off-reports/client-review-links', body: {
      'reportId': reportId,
      'clientEmail': clientEmail,
      if (expiresInSeconds != null) 'expiresInSeconds': expiresInSeconds,
    });
  }

  /// Get sign-off report and performance metrics via secure token (no auth required)
  Future<ApiResponse> getClientReviewByToken(String token) async {
    debugPrint('🔵 Fetching client review by token');
    return await _apiClient.get('/sign-off-reports/client-review/$token',
        requireAuth: false);
  }

  Future<ApiResponse> aiChat(List<Map<String, dynamic>> messages,
      {double? temperature, int? maxTokens}) async {
    final body = {
      'messages': messages,
      if (temperature != null) 'temperature': temperature,
      if (maxTokens != null) 'max_tokens': maxTokens,
    };
    final resp = await _apiClient.post('/ai/chat', body: body);
    if (resp.statusCode == 429) {
      int seconds = 2;
      try {
        final raw = resp.data;
        if (raw is Map) {
          final ra = raw['retry_after'];
          if (ra != null) {
            final parsed = int.tryParse(ra.toString());
            if (parsed != null && parsed > 0 && parsed <= 30) seconds = parsed;
          }
        }
      } catch (_) {}
      await Future.delayed(Duration(seconds: seconds));
      return await _apiClient.post('/ai/chat', body: body);
    }
    return resp;
  }

  Future<ApiResponse> aiSuggestions() async {
    return await _apiClient.get('/ai/suggestions');
  }

  // Project endpoints
  Future<ApiResponse> getProjects(
      {int page = 1, int limit = 1000, String? search}) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    return await _apiClient.get('/projects', queryParams: queryParams);
  }

  Future<ApiResponse> getProject(String projectId) async {
    return await _apiClient.get('/projects/$projectId');
  }

  Future<ApiResponse> createProject(Map<String, dynamic> projectData) async {
    return await _apiClient.post('/projects', body: projectData);
  }

  Future<ApiResponse> updateProject(
      String projectId, Map<String, dynamic> updates) async {
    return await _apiClient.put('/projects/$projectId', body: updates);
  }

  Future<ApiResponse> deleteProject(String projectId) async {
    return await _apiClient.delete('/projects/$projectId');
  }

  Future<ApiResponse> remindProjectOwner(String projectId,
      {bool force = false}) async {
    final body = <String, dynamic>{};
    if (force) {
      body['force'] = true;
    }
    return await _apiClient.post('/projects/$projectId/remind-owner',
        body: body.isEmpty ? null : body);
  }

  // Project member management
  Future<ApiResponse> getProjectMembers(String projectId) async {
    return await _apiClient.get('/projects/$projectId/members');
  }

  Future<ApiResponse> addProjectMember(
      String projectId, Map<String, dynamic> memberData) async {
    return await _apiClient.post('/projects/$projectId/members',
        body: memberData);
  }

  Future<ApiResponse> removeProjectMember(
      String projectId, String userId) async {
    return await _apiClient.delete('/projects/$projectId/members/$userId');
  }

  // Project deliverable linking
  Future<ApiResponse> linkDeliverableToProject(
      String projectId, String deliverableId) async {
    // Implement by updating the deliverable's project_id field
    return await _apiClient.put('/deliverables/$deliverableId', body: {
      'project_id': projectId,
    });
  }

  Future<ApiResponse> unlinkDeliverableFromProject(
      String projectId, String deliverableId) async {
    // Implement by clearing the deliverable's project_id field
    return await _apiClient.put('/deliverables/$deliverableId', body: {
      'project_id': null,
    });
  }

  // Project sprint association
  Future<ApiResponse> associateSprintWithProject(
      String projectId, List<String> sprintIds) async {
    return await _apiClient.post('/projects/$projectId/sprints', body: {
      'sprintIds': sprintIds,
    });
  }

  Future<ApiResponse> dissociateSprintFromProject(
      String projectId, String sprintId) async {
    return await _apiClient.delete('/projects/$projectId/sprints/$sprintId');
  }

  // Release readiness endpoints
  Future<ApiResponse> getReleaseReadinessChecks(String deliverableId) async {
    return await _apiClient
        .get('/deliverables/$deliverableId/readiness-checks');
  }

  Future<ApiResponse> updateReadinessCheck(
      String deliverableId, Map<String, dynamic> checkData) async {
    return await _apiClient.put('/deliverables/$deliverableId/readiness-checks',
        body: checkData);
  }

  // Notification endpoints
  Future<ApiResponse> getNotifications(
      {int page = 1, int limit = 20, bool? unreadOnly}) async {
    final skip = (page <= 1) ? 0 : (page - 1) * limit;
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
      if (unreadOnly != null) 'unread_only': unreadOnly.toString(),
    };
    return await _apiClient.get('/notifications/me', queryParams: queryParams);
  }

  Future<ApiResponse> markNotificationAsRead(String notificationId) async {
    return await _apiClient.put('/notifications/$notificationId/read');
  }

  Future<ApiResponse> markAllNotificationsAsRead() async {
    return await _apiClient.put('/notifications/read-all');
  }

  Future<ApiResponse> simulateReportReminder(
      {String? reportId,
      bool force = true,
      String? recipientRole,
      String? recipientId}) async {
    final body = <String, dynamic>{};
    if (reportId != null && reportId.isNotEmpty) body['reportId'] = reportId;
    if (force) body['force'] = true;
    if (recipientRole != null && recipientRole.isNotEmpty) {
      body['recipientRole'] = recipientRole;
    }
    if (recipientId != null && recipientId.isNotEmpty) {
      body['recipientId'] = recipientId;
    }
    return await _apiClient.post('/system/simulate-report-reminder',
        body: body);
  }

  Future<ApiResponse> sendReminderForReport(
      String reportId, String recipientRole,
      {String? recipientId}) async {
    return await simulateReportReminder(
        reportId: reportId,
        recipientRole: recipientRole,
        recipientId: recipientId,
        force: true);
  }

  Future<ApiResponse> deleteNotification(String notificationId) async {
    return await _apiClient.delete('/notifications/$notificationId');
  }

  // Dashboard and analytics endpoints
  Future<ApiResponse> getDashboardData() async {
    return await _apiClient.get('/analytics/dashboard');
  }

  Future<ApiResponse> getAnalytics(String type,
      {Map<String, String>? filters}) async {
    return await _apiClient.get('/analytics/$type', queryParams: filters);
  }

  Future<ApiResponse> getAuditLogs(
      {int skip = 0, int limit = 100, String? action, String? userId}) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    if (action != null && action.isNotEmpty) {
      queryParams['action'] = action;
    }
    if (userId != null && userId.isNotEmpty) {
      queryParams['user_id'] = userId;
    }

    final response =
        await _apiClient.get('/audit-logs', queryParams: queryParams);

    // If the endpoint doesn't exist or returns error, provide empty response
    if (!response.isSuccess) {
      debugPrint('Audit endpoint not available, returning empty response');
      return ApiResponse.success(
        {
          'audit_logs': [],
          'items': [],
          'logs': [],
          'total': 0,
          'total_count': 0,
          'skip': skip,
          'limit': limit,
          'has_more': false,
        },
        200,
      );
    }

    return response;
  }

  // File upload endpoints
  Future<ApiResponse> uploadFile(
      String filePath, String fileName, String fileType) async {
    return await _apiClient.uploadFile(
        '/files/upload', filePath, fileName, fileType);
  }

  Future<ApiResponse> deleteFile(String fileId) async {
    return await _apiClient.delete('/files/$fileId');
  }

  // System configuration endpoints
  Future<ApiResponse> getSystemSettings() async {
    return await _apiClient.get('/system/settings');
  }

  Future<ApiResponse> updateSystemSettings(
      Map<String, dynamic> settings) async {
    return await _apiClient.put('/system/settings', body: settings);
  }

  Future<ApiResponse> getHealthCheck() async {
    return await _apiClient.get('/health');
  }

  // System administration endpoints
  Future<ApiResponse> createBackup() async {
    return await _apiClient.post('/system/backup');
  }

  Future<ApiResponse> restoreBackup() async {
    return await _apiClient.post('/system/restore');
  }

  Future<ApiResponse> clearCache() async {
    return await _apiClient.post('/system/cache/clear');
  }

  Future<ApiResponse> optimizeDatabase() async {
    return await _apiClient.post('/system/optimize-database');
  }

  // Ticket endpoints
  Future<ApiResponse> updateTicketStatus(
      String ticketId, Map<String, dynamic> updates) async {
    return await _apiClient.put('/tickets/$ticketId/status', body: updates);
  }

  Future<ApiResponse> updateTicket(
      String ticketId, Map<String, dynamic> updates) async {
    return await _apiClient.put('/tickets/$ticketId', body: updates);
  }

  // System statistics endpoint
  Future<ApiResponse> getSystemStats() async {
    return await _apiClient.get('/system/stats');
  }

  // System maintenance endpoints
  Future<ApiResponse> toggleMaintenanceMode(bool enabled,
      {String? message}) async {
    return await _apiClient.post(
      '/system/maintenance',
      body: {
        'enabled': enabled,
        'message': message,
      },
    );
  }

  // System backup management
  Future<ApiResponse> listBackups() async {
    return await _apiClient.get('/system/backups');
  }

  // Audit logs endpoint (real implementation)
  Future<ApiResponse> getRealAuditLogs(
      {int skip = 0, int limit = 100, String? action, String? userId}) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    if (action != null && action.isNotEmpty) {
      queryParams['action'] = action;
    }
    if (userId != null && userId.isNotEmpty) {
      queryParams['user_id'] = userId;
    }

    return await _apiClient.get('/audit-logs', queryParams: queryParams);
  }

  Future<ApiResponse> getSystemHealth() async {
    return await _apiClient.get('/monitoring/health');
  }

  // User settings endpoints
  Future<ApiResponse> getUserSettings() async {
    return await _apiClient.get('/settings/me');
  }

  Future<ApiResponse> updateUserSettings(Map<String, dynamic> settings) async {
    return await _apiClient.put('/settings/me', body: settings);
  }

  Future<ApiResponse> resetUserSettings() async {
    return await _apiClient.delete('/settings/me');
  }

  Future<ApiResponse> exportUserData() async {
    return await _apiClient.get('/user/data/export');
  }

  Future<ApiResponse> clearUserCache() async {
    return await _apiClient.delete('/user/cache');
  }

  // Sprint tickets endpoints
  Future<ApiResponse> getSprintTickets(String sprintId) async {
    return await _apiClient.get('/sprints/$sprintId/tickets');
  }

  // File listing endpoint
  Future<ApiResponse> listFiles({String? prefix}) async {
    final queryParams = prefix != null ? {'prefix': prefix} : null;
    return await _apiClient.get('/files', queryParams: queryParams);
  }

  // Email verification endpoints
  Future<ApiResponse> resendVerificationEmail(String email) async {
    return await _apiClient.post(
      '/auth/resend-verification',
      body: {
        'email': email,
      },
    );
  }

  Future<ApiResponse> verifyEmail(String email, String verificationCode) async {
    debugPrint(
        '🔍 verifyEmail called with: email=$email, code=$verificationCode');
    final response = await _apiClient.post(
      '/auth/verify-email',
      body: {
        'email': email,
        'code': verificationCode,
      },
    );
    debugPrint('📡 verifyEmail response: ${response.toString()}');
    return response;
  }

  Future<ApiResponse> checkEmailVerificationStatus(String email) async {
    return await _apiClient.get(
      '/auth/verification-status',
      queryParams: {
        'email': email,
      },
    );
  }

// Approval requests endpoints
  Future<ApiResponse> getApprovalRequests(
      {String? status,
      String? deliverableId,
      String? requestedBy,
      int page = 1,
      int limit = 100}) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null) queryParams['status'] = status;
    if (deliverableId != null) queryParams['deliverable_id'] = deliverableId;
    if (requestedBy != null) queryParams['requested_by'] = requestedBy;

    return await _apiClient.get('/approvals', queryParams: queryParams);
  }

  Future<ApiResponse> getApprovalRequest(String id) async {
    return await _apiClient.get('/approvals/$id');
  }

  Future<ApiResponse> approveRequest(
      String id, Map<String, dynamic> approvalData) async {
    return await _apiClient.put('/approvals/$id/approve', body: approvalData);
  }

  Future<ApiResponse> rejectRequest(
      String id, Map<String, dynamic> rejectionData) async {
    return await _apiClient.put('/approvals/$id/reject', body: rejectionData);
  }

  Future<ApiResponse> sendReminder(String id) async {
    return await _apiClient.put('/approvals/$id/remind');
  }

  Future<ApiResponse> getApprovalMetrics() async {
    return await _apiClient.get('/approvals/stats/metrics');
  }

  // Helper methods for data transformation
  User? parseUserFromResponse(ApiResponse response) {
    if (!response.isSuccess || response.data == null) {
      return null;
    }

    try {
      // The user data might be nested under 'user' key or at the root level
      // Handle different response structures from different endpoints
      final userData = response.data!['user'] ?? response.data!;

      if (userData == null || userData.isEmpty) {
        return null;
      }

      // Create a proper user object for the User.fromJson method
      // Handle both snake_case and camelCase fields from backend
      // Handle different field names from different backend endpoints

      // Convert backend role string to UserRole enum name format
      final backendRole = userData['role']?.toString() ?? '';
      String userRoleForParsing;

      switch (backendRole.toLowerCase()) {
        case 'client':
          userRoleForParsing = 'client';
          break;
        case 'clientreviewer':
        case 'client_reviewer':
          userRoleForParsing = 'clientReviewer';
          break;
        case 'deliverylead':
        case 'delivery_lead':
          userRoleForParsing = 'deliveryLead';
          break;
        case 'systemadmin':
        case 'system_admin':
          userRoleForParsing = 'systemAdmin';
          break;
        case 'teammember':
        case 'team_member':
        default:
          userRoleForParsing = 'teamMember';
          break;
      }

      final firstName = userData['first_name'] ??
          userData['firstName'] ??
          userData['firstname'] ??
          '';
      final lastName = userData['last_name'] ??
          userData['lastName'] ??
          userData['lastname'] ??
          '';
      final combinedName = ('$firstName $lastName').trim();
      final rawEmail = userData['email']?.toString() ?? '';
      final emailLocal =
          rawEmail.contains('@') ? rawEmail.split('@')[0] : rawEmail;
      final resolvedName = () {
        final n = (userData['name'] ?? userData['username'] ?? combinedName)
            .toString()
            .trim();
        return n.isNotEmpty ? n : emailLocal;
      }();

      final isActiveRaw =
          userData['is_active'] ?? userData['isActive'] ?? userData['isactive'];
      bool isActiveComputed;
      if (isActiveRaw == null) {
        final statusStr = (userData['status'] ?? '').toString().toLowerCase();
        isActiveComputed = statusStr.isEmpty ? true : statusStr == 'active';
      } else {
        final s = isActiveRaw.toString().toLowerCase();
        isActiveComputed = s == 'true' || s == '1';
      }

      final userJsonForParsing = {
        'id': userData['id']?.toString(),
        'email': userData['email'],
        'name': resolvedName,
        'role': userRoleForParsing,
        'avatarUrl': userData['avatar_url'] ??
            userData['avatarUrl'] ??
            userData['avatarurl'],
        'createdAt': userData['created_at'] ??
            userData['createdAt'] ??
            userData['createdat'] ??
            DateTime.now().toIso8601String(),
        'lastLoginAt': userData['last_login'] ??
            userData['last_login_at'] ??
            userData['lastLoginAt'] ??
            userData['lastlogin'] ??
            userData['lastLogin'],
        'isActive': isActiveComputed,
        'projectIds': userData['project_ids'] ??
            userData['projectIds'] ??
            userData['projectids'] ??
            [],
        'preferences': userData['preferences'] ?? {},
        'emailVerified': userData['email_verified'] ??
            userData['emailVerified'] ??
            userData['emailverified'] ??
            false,
        'emailVerifiedAt': userData['email_verified_at'] ??
            userData['emailVerifiedAt'] ??
            userData['emailverifiedat'],
      };

      return User.fromJson(userJsonForParsing);
    } catch (e) {
      debugPrint('Error parsing user: $e');
      return null;
    }
  }

  List<Deliverable> parseDeliverablesFromResponse(ApiResponse response) {
    if (!response.isSuccess || response.data == null) return [];

    try {
      final List<dynamic> items =
          response.data!['data'] ?? response.data!['deliverables'] ?? [];
      return items.map((item) => Deliverable.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error parsing deliverables: $e');
      return [];
    }
  }

  List<SprintMetrics> parseSprintMetricsFromResponse(ApiResponse response) {
    if (!response.isSuccess || response.data == null) return [];

    try {
      final List<dynamic> items =
          response.data!['data'] ?? response.data!['metrics'] ?? [];
      return items.map((item) => SprintMetrics.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error parsing sprint metrics: $e');
      return [];
    }
  }

  List<SignOffReport> parseSignOffReportsFromResponse(ApiResponse response) {
    if (!response.isSuccess || response.data == null) return [];

    try {
      final dynamic raw = response.data;
      final List<dynamic> items = raw is List
          ? raw
          : (raw['data'] ?? raw['reports'] ?? raw['items'] ?? []);
      return items.map((item) => SignOffReport.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error parsing sign-off reports: $e');
      return [];
    }
  }

  // QA-specific endpoints
  Future<ApiResponse> getTestQueue() async {
    return await _apiClient.get('/qa/test-queue');
  }

  Future<ApiResponse> getQualityMetrics() async {
    return await _apiClient.get('/qa/quality-metrics');
  }

  Future<ApiResponse> getBugReports({int limit = 10}) async {
    final queryParams = {'limit': limit.toString()};
    return await _apiClient.get('/qa/bug-reports', queryParams: queryParams);
  }

  Future<ApiResponse> getTestCoverage() async {
    return await _apiClient.get('/qa/test-coverage');
  }

  // Approval endpoints

  Future<ApiResponse> createApprovalRequest(
      Map<String, dynamic> requestData) async {
    return await _apiClient.post('/approvals', body: requestData);
  }

  // System endpoints
  Future<ApiResponse> triggerEscalation({bool force = false}) async {
    return await _apiClient
        .post('/system/trigger-escalation', body: {'force': force});
  }
}

const String _reportsKey = 'cached_signoff_reports';
Future<void> _saveCachedReports(List<dynamic> list) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reportsKey, jsonEncode(list));
  } catch (e) {
    debugPrint('❌ Error caching reports: $e');
  }
}

Future<void> _prependCachedReport(Map<String, dynamic> report) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_reportsKey);
    final list = (s != null && s.isNotEmpty)
        ? List<Map<String, dynamic>>.from(jsonDecode(s))
        : <Map<String, dynamic>>[];
    list.insert(0, report);
    await prefs.setString(_reportsKey, jsonEncode(list));
  } catch (e) {
    debugPrint('❌ Error updating cached reports: $e');
  }
}

Future<void> _removeCachedReport(String reportId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_reportsKey);
    if (s == null || s.isEmpty) return;
    final list = List<Map<String, dynamic>>.from(jsonDecode(s));
    list.removeWhere((e) => (e['id']?.toString() ?? '') == reportId);
    await prefs.setString(_reportsKey, jsonEncode(list));
  } catch (e) {
    debugPrint('❌ Error removing cached report: $e');
  }
}

Future<void> _updateCachedReportStatus(String reportId, String status) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_reportsKey);
    if (s == null || s.isEmpty) return;
    final list = List<Map<String, dynamic>>.from(jsonDecode(s));
    for (final e in list) {
      if ((e['id']?.toString() ?? '') == reportId) {
        e['status'] = status;
        break;
      }
    }
    await prefs.setString(_reportsKey, jsonEncode(list));
  } catch (e) {
    debugPrint('❌ Error updating cached report: $e');
  }
}
