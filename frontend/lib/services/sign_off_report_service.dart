import '../services/auth_service.dart';
import '../services/api_client.dart';

class SignOffReportService {
  final AuthService _authService;
  final ApiClient _apiClient = ApiClient();

  SignOffReportService(this._authService);

  // Get all sign-off reports with filters
  Future<ApiResponse> getSignOffReports({
    String? status,
    String? search,
    String? deliverableId,
    String? projectId,
    String? sprintId,
    String? from,
    String? to,
  }) async {
    try {
      await _apiClient.initialize();
      if (_authService.accessToken == null) return ApiResponse.error('Not authenticated');
      final queryParams = <String, String>{
        if (status != null) 'status': status,
        if (search != null) 'search': search,
        if (deliverableId != null) 'deliverableId': deliverableId,
        if (projectId != null) 'projectId': projectId,
        if (sprintId != null) 'sprintId': sprintId,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      };
      return await _apiClient.get('/sign-off-reports', queryParams: queryParams);
    } catch (e) {
      return ApiResponse.error('Error loading sign-off reports: $e');
    }
  }

  // Send reminder for a sign-off report review
  Future<ApiResponse> sendReminder(String reportId) async {
    try {
      await _apiClient.initialize();
      if (_authService.accessToken == null) return ApiResponse.error('Not authenticated');
      return await _apiClient.post('/sign-off-reports/$reportId/remind');
    } catch (e) {
      return ApiResponse.error('Error sending reminder: $e');
    }
  }

  // Escalate a sign-off report
  Future<ApiResponse> escalateReport(String reportId) async {
    try {
      await _apiClient.initialize();
      if (_authService.accessToken == null) return ApiResponse.error('Not authenticated');
      return await _apiClient.post('/sign-off-reports/$reportId/escalate');
    } catch (e) {
      return ApiResponse.error('Error escalating report: $e');
    }
  }

  // Get single sign-off report
  Future<ApiResponse> getSignOffReport(String reportId) async {
    try {
      await _apiClient.initialize();
      if (_authService.accessToken == null) return ApiResponse.error('Not authenticated');
      return await _apiClient.get('/sign-off-reports/$reportId');
    } catch (e) {
      return ApiResponse.error('Error loading sign-off report: $e');
    }
  }

  // Get audit history for sign-off report
  Future<ApiResponse> getReportAudit(String reportId) async {
    try {
      await _apiClient.initialize();
      if (_authService.accessToken == null) return ApiResponse.error('Not authenticated');
      return await _apiClient.get('/audit/signoff/$reportId');
    } catch (e) {
      return ApiResponse.error('Error loading audit history: $e');
    }
  }

  // Submit report
  Future<ApiResponse> submitReport(String reportId) async {
    try {
      await _apiClient.initialize();
      if (_authService.accessToken == null) return ApiResponse.error('Not authenticated');
      return await _apiClient.post('/sign-off-reports/$reportId/submit');
    } catch (e) {
      return ApiResponse.error('Error submitting report: $e');
    }
  }

  // Approve report
  Future<ApiResponse> approveReport(String reportId, {String? comment, String? digitalSignature}) async {
    try {
      await _apiClient.initialize();
      if (_authService.accessToken == null) return ApiResponse.error('Not authenticated');
      return await _apiClient.post('/sign-off-reports/$reportId/approve', body: {
        if (comment != null) 'comment': comment,
        if (digitalSignature != null) 'digitalSignature': digitalSignature,
      });
    } catch (e) {
      return ApiResponse.error('Error approving report: $e');
    }
  }

  // Seal report
  Future<ApiResponse> sealReport(String reportId) async {
    try {
      await _apiClient.initialize();
      if (_authService.accessToken == null) return ApiResponse.error('Not authenticated');
      return await _apiClient.post('/sign-off-reports/$reportId/seal');
    } catch (e) {
      return ApiResponse.error('Error sealing report: $e');
    }
  }

  // Archive report
  Future<ApiResponse> archiveReport(String reportId) async {
    try {
      await _apiClient.initialize();
      if (_authService.accessToken == null) return ApiResponse.error('Not authenticated');
      return await _apiClient.post('/sign-off-reports/$reportId/archive');
    } catch (e) {
      return ApiResponse.error('Error archiving report: $e');
    }
  }

  // Request changes
  Future<ApiResponse> requestChanges(String reportId, {String? changeRequestDetails, required String digitalSignature}) async {
    try {
      await _apiClient.initialize();
      if (_authService.accessToken == null) return ApiResponse.error('Not authenticated');
      return await _apiClient.post('/sign-off-reports/$reportId/request-changes', body: {
        if (changeRequestDetails != null) 'changeRequestDetails': changeRequestDetails,
        'digitalSignature': digitalSignature,
      });
    } catch (e) {
      return ApiResponse.error('Error requesting changes: $e');
    }
  }

  Future<ApiResponse> rejectReport(String reportId, {String? comment, required String digitalSignature}) async {
    try {
      await _apiClient.initialize();
      if (_authService.accessToken == null) return ApiResponse.error('Not authenticated');
      return await _apiClient.post('/sign-off-reports/$reportId/reject', body: {
        if (comment != null) 'comment': comment,
        'digitalSignature': digitalSignature,
      });
    } catch (e) {
      return ApiResponse.error('Error rejecting report: $e');
    }
  }

  // Create sign-off report
  Future<ApiResponse> createSignOffReport({
    required String deliverableId,
    required String reportTitle,
    required String reportContent,
    List<String>? sprintIds,
    String? sprintPerformanceData,
    String? knownLimitations,
    String? nextSteps,
  }) async {
    try {
      await _apiClient.initialize();
      if (_authService.accessToken == null) return ApiResponse.error('Not authenticated');
      return await _apiClient.post('/sign-off-reports', body: {
        'deliverableId': deliverableId,
        'reportTitle': reportTitle,
        'reportContent': reportContent,
        if (sprintIds != null) 'sprintIds': sprintIds,
        if (sprintPerformanceData != null) 'sprintPerformanceData': sprintPerformanceData,
        if (knownLimitations != null) 'knownLimitations': knownLimitations,
        if (nextSteps != null) 'nextSteps': nextSteps,
      });
    } catch (e) {
      return ApiResponse.error('Error creating sign-off report: $e');
    }
  }

  // Update sign-off report
  Future<ApiResponse> updateSignOffReport({
    required String reportId,
    String? reportTitle,
    String? reportContent,
    List<String>? sprintIds,
    String? sprintPerformanceData,
    String? knownLimitations,
    String? nextSteps,
  }) async {
    try {
      await _apiClient.initialize();
      if (_authService.accessToken == null) return ApiResponse.error('Not authenticated');
      return await _apiClient.put('/sign-off-reports/$reportId', body: {
        if (reportTitle != null) 'reportTitle': reportTitle,
        if (reportContent != null) 'reportContent': reportContent,
        if (sprintIds != null) 'sprintIds': sprintIds,
        if (sprintPerformanceData != null) 'sprintPerformanceData': sprintPerformanceData,
        if (knownLimitations != null) 'knownLimitations': knownLimitations,
        if (nextSteps != null) 'nextSteps': nextSteps,
      });
    } catch (e) {
      return ApiResponse.error('Error updating sign-off report: $e');
    }
  }
}

