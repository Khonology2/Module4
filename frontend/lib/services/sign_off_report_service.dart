import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../config/api_config.dart';

class SignOffReportService {
  final AuthService _authService;
  final String _baseUrl = ApiConfig.getFullUrl('/sign-off-reports');

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
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('Not authenticated');
      }

      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        if (status != null) 'status': status,
        if (search != null) 'search': search,
        if (deliverableId != null) 'deliverableId': deliverableId,
        if (projectId != null) 'projectId': projectId,
        if (sprintId != null) 'sprintId': sprintId,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      },);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      // Check if response is HTML (error pages) instead of JSON
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('text/html') || response.body.trim().startsWith('<!DOCTYPE')) {
        String errorMsg = 'Server returned HTML instead of JSON';
        if (response.statusCode == 404) {
          errorMsg = 'Endpoint not found (404). Check the API endpoint path.';
        } else if (response.statusCode >= 500) {
          errorMsg = 'Server error (${response.statusCode})';
        }
        return ApiResponse.error(errorMsg, response.statusCode);
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return ApiResponse.success(decoded, response.statusCode);
        }
        if (decoded is Map<String, dynamic>) {
          final data = decoded.containsKey('data') ? decoded['data'] : decoded;
          return ApiResponse.success(data, response.statusCode);
        }
        return ApiResponse.success(decoded, response.statusCode);
      } else {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            return ApiResponse.error(decoded['error'] ?? decoded['message'] ?? 'Failed to load sign-off reports', response.statusCode);
          }
          return ApiResponse.error('Failed to load sign-off reports', response.statusCode);
        } catch (e) {
          return ApiResponse.error('Failed to load sign-off reports (${response.statusCode})', response.statusCode);
        }
      }
    } catch (e) {
      return ApiResponse.error('Error loading sign-off reports: $e');
    }
  }

  // Send reminder for a sign-off report review
  Future<ApiResponse> sendReminder(String reportId) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/$reportId/remind'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResponse.success(data, response.statusCode);
      } else {
        final data = jsonDecode(response.body);
        return ApiResponse.error(data['error'] ?? 'Failed to send reminder');
      }
    } catch (e) {
      return ApiResponse.error('Error sending reminder: $e');
    }
  }

  // Escalate a sign-off report
  Future<ApiResponse> escalateReport(String reportId) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/$reportId/escalate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResponse.success(data, response.statusCode);
      } else {
        final data = jsonDecode(response.body);
        return ApiResponse.error(data['error'] ?? 'Failed to escalate report');
      }
    } catch (e) {
      return ApiResponse.error('Error escalating report: $e');
    }
  }

  // Get single sign-off report
  Future<ApiResponse> getSignOffReport(String reportId) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('Not authenticated');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/$reportId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      // Check if response is HTML (error pages) instead of JSON
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('text/html') || response.body.trim().startsWith('<!DOCTYPE')) {
        String errorMsg = 'Server returned HTML instead of JSON';
        if (response.statusCode == 404) {
          errorMsg = 'Report not found (404)';
        } else if (response.statusCode >= 500) {
          errorMsg = 'Server error (${response.statusCode})';
        }
        return ApiResponse.error(errorMsg, response.statusCode);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Backend returns { success: true, data: {...} }
        // Extract the data field for consistency with ApiClient
        return ApiResponse.success(data['data'] ?? data, response.statusCode);
      } else {
        try {
          final data = jsonDecode(response.body);
          return ApiResponse.error(data['error'] ?? data['message'] ?? 'Failed to load sign-off report', response.statusCode);
        } catch (e) {
          return ApiResponse.error('Failed to load sign-off report (${response.statusCode})', response.statusCode);
        }
      }
    } catch (e) {
      return ApiResponse.error('Error loading sign-off report: $e');
    }
  }

  // Get audit history for sign-off report
  Future<ApiResponse> getReportAudit(String reportId) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('Not authenticated');
      }

      final response = await http.get(
        Uri.parse(ApiConfig.getFullUrl('/audit/signoff/$reportId')),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      // Check if response is HTML (error pages) instead of JSON
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('text/html') || response.body.trim().startsWith('<!DOCTYPE')) {
        String errorMsg = 'Server returned HTML instead of JSON';
        if (response.statusCode == 404) {
          errorMsg = 'Audit history not found (404)';
        } else if (response.statusCode >= 500) {
          errorMsg = 'Server error (${response.statusCode})';
        }
        return ApiResponse.error(errorMsg, response.statusCode);
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final auditData = (decoded is Map<String, dynamic> && decoded.containsKey('data'))
            ? decoded['data']
            : decoded;
        return ApiResponse.success({'audit': auditData}, response.statusCode);
      } else {
        try {
          final data = jsonDecode(response.body);
          return ApiResponse.error(data['error'] ?? data['message'] ?? 'Failed to load audit history', response.statusCode);
        } catch (e) {
          return ApiResponse.error('Failed to load audit history (${response.statusCode})', response.statusCode);
        }
      }
    } catch (e) {
      return ApiResponse.error('Error loading audit history: $e');
    }
  }

  // Submit report
  Future<ApiResponse> submitReport(String reportId) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/$reportId/submit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResponse.success(data, response.statusCode);
      } else {
        final data = jsonDecode(response.body);
        return ApiResponse.error(data['error'] ?? 'Failed to submit report');
      }
    } catch (e) {
      return ApiResponse.error('Error submitting report: $e');
    }
  }

  // Approve report
  Future<ApiResponse> approveReport(String reportId, {String? comment, String? digitalSignature}) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/$reportId/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          if (comment != null) 'comment': comment,
          if (digitalSignature != null) 'digitalSignature': digitalSignature,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResponse.success(data, response.statusCode);
      } else {
        final data = jsonDecode(response.body);
        return ApiResponse.error(data['error'] ?? 'Failed to approve report');
      }
    } catch (e) {
      return ApiResponse.error('Error approving report: $e');
    }
  }

  // Seal report
  Future<ApiResponse> sealReport(String reportId) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/$reportId/seal'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResponse.success(data, response.statusCode);
      } else {
        final data = jsonDecode(response.body);
        return ApiResponse.error(data['error'] ?? 'Failed to seal report');
      }
    } catch (e) {
      return ApiResponse.error('Error sealing report: $e');
    }
  }

  // Archive report
  Future<ApiResponse> archiveReport(String reportId) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/$reportId/archive'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResponse.success(data, response.statusCode);
      } else {
        final data = jsonDecode(response.body);
        return ApiResponse.error(data['error'] ?? 'Failed to archive report');
      }
    } catch (e) {
      return ApiResponse.error('Error archiving report: $e');
    }
  }

  // Request changes
  Future<ApiResponse> requestChanges(String reportId, String changeRequestDetails) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/$reportId/request-changes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'changeRequestDetails': changeRequestDetails,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResponse.success(data, response.statusCode);
      } else {
        final data = jsonDecode(response.body);
        return ApiResponse.error(data['error'] ?? 'Failed to request changes');
      }
    } catch (e) {
      return ApiResponse.error('Error requesting changes: $e');
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
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('Not authenticated');
      }

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'deliverableId': deliverableId,
          'reportTitle': reportTitle,
          'reportContent': reportContent,
          if (sprintIds != null) 'sprintIds': sprintIds,
          if (sprintPerformanceData != null) 'sprintPerformanceData': sprintPerformanceData,
          if (knownLimitations != null) 'knownLimitations': knownLimitations,
          if (nextSteps != null) 'nextSteps': nextSteps,
        }),
      );

      // Check if response is HTML (error pages) instead of JSON
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('text/html') || response.body.trim().startsWith('<!DOCTYPE')) {
        String errorMsg = 'Server returned HTML instead of JSON';
        if (response.statusCode == 404) {
          errorMsg = 'Endpoint not found (404). Check the API endpoint path.';
        } else if (response.statusCode >= 500) {
          errorMsg = 'Server error (${response.statusCode})';
        }
        return ApiResponse.error(errorMsg, response.statusCode);
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return ApiResponse.success(data['data'] ?? data, response.statusCode);
      } else {
        try {
          final data = jsonDecode(response.body);
          return ApiResponse.error(data['error'] ?? data['message'] ?? 'Failed to create sign-off report', response.statusCode);
        } catch (e) {
          return ApiResponse.error('Failed to create sign-off report (${response.statusCode})', response.statusCode);
        }
      }
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
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('Not authenticated');
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/$reportId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          if (reportTitle != null) 'reportTitle': reportTitle,
          if (reportContent != null) 'reportContent': reportContent,
          if (sprintIds != null) 'sprintIds': sprintIds,
          if (sprintPerformanceData != null) 'sprintPerformanceData': sprintPerformanceData,
          if (knownLimitations != null) 'knownLimitations': knownLimitations,
          if (nextSteps != null) 'nextSteps': nextSteps,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResponse.success(data, response.statusCode);
      } else {
        final data = jsonDecode(response.body);
        return ApiResponse.error(data['error'] ?? 'Failed to update sign-off report');
      }
    } catch (e) {
      return ApiResponse.error('Error updating sign-off report: $e');
    }
  }
}

