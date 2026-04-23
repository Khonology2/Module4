import 'dart:convert';
import 'package:flutter/foundation.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/system_metrics.dart';
import '../models/project.dart';
import 'backend_api_service.dart';
import '../config/environment.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
static final String baseUrl = Environment.apiBaseUrl;
  
  // Get auth headers with token
  static Future<Map<String, String>> _getHeaders() async {
    final authService = AuthService();
    await authService.initialize();
    final token = authService.accessToken;
    
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }
  
  static Future<Map<String, String>> getAuthHeaders() async {
    return _getHeaders();
  }
  
  // Initialize the service
  static Future<void> initialize() async {
    debugPrint('API Service initialized');
  }
  
  // Authentication methods
  static Future<Map<String, dynamic>?> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String company,
    required String role,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'firstName': firstName,
          'lastName': lastName,
          'company': company,
          'role': role,
        }),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 409) {
        // User already exists - return error details
        final responseBody = jsonDecode(response.body);
        debugPrint('Sign up failed: User already exists - ${responseBody['error'] ?? response.body}');
        return {
          'error': responseBody['error'] ?? 'User already exists',
          'message': responseBody['message'] ?? 'A user with this email already exists',
          'statusCode': response.statusCode,
        };
      } else {
        debugPrint('Sign up failed: ${response.statusCode} - ${response.body}');
        return {
          'error': 'Registration failed',
          'message': 'Failed to create account. Please try again.',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      debugPrint('Error during sign up: $e');
      return {
        'error': 'Network error',
        'message': 'Failed to connect to server. Please check your connection.',
      };
    }
  }
  
  static Future<Map<String, dynamic>?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('Sign in failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error during sign in: $e');
      return null;
    }
  }
  
  // Database methods for deliverables
  static Future<List<Map<String, dynamic>>> getDeliverables() async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.getDeliverables();
      
      if (response.isSuccess && response.data != null) {
        final dynamic raw = response.data;
        if (raw is List) {
          return raw.cast<Map<String, dynamic>>();
        }
        final List<dynamic> items = (raw is Map)
            ? (raw['data'] ?? raw['deliverables'] ?? raw['items'] ?? [])
            : [];
        return items.cast<Map<String, dynamic>>();
      } else {
        debugPrint('Failed to fetch deliverables: ${response.statusCode} - ${response.error}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching deliverables: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getDeliverable(String deliverableId) async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.getDeliverable(deliverableId);
      
      if (response.isSuccess && response.data != null) {
        return response.data!['data'] ?? response.data!['deliverable'];
      } else {
        debugPrint('Failed to fetch deliverable: ${response.statusCode} - ${response.error}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching deliverable: $e');
      return null;
    }
  }
  
  static Future<Map<String, dynamic>?> createDeliverable({
    required String title,
    required String description,
    required String definitionOfDone,
    required String status,
    required String assignedTo,
    required String createdBy,
    List<String>? sprintIds,
  }) async {
    try {
      debugPrint('Creating deliverable: $title');
      
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/deliverables'),
        headers: headers,
        body: jsonEncode({
          'title': title,
          'description': description,
          'definition_of_done': definitionOfDone,
          'status': status,
          'assigned_to': assignedTo,
          'created_by': createdBy,
        }),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          debugPrint('✅ Deliverable created successfully');
          return data['data'];
        }
      }
      
      // Parse error details from response
      try {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['details'] ?? errorData['error'] ?? 'Unknown error';
        final errorCode = errorData['code'];
        final errorDetail = errorData['detail'];
        
        debugPrint('❌ Failed to create deliverable: ${response.statusCode}');
        debugPrint('   Error: $errorMessage');
        if (errorCode != null) debugPrint('   Code: $errorCode');
        if (errorDetail != null) debugPrint('   Detail: $errorDetail');
        debugPrint('   Full response: ${response.body}');
      } catch (e) {
        debugPrint('❌ Failed to create deliverable: ${response.statusCode}');
        debugPrint('   Response body: ${response.body}');
      }
      
      return null;
    } catch (e) {
      debugPrint('Error creating deliverable: $e');
      return null;
    }
  }
  
  static Future<bool> updateTicketStatus({
    required String issueId,
    required String status,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/tickets/$issueId/status'),
        headers: headers,
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating ticket status: $e');
      return false;
    }
  }

  
  static Future<void> updateDeliverableStatus({
    required String id,
    required String status,
  }) async {
    try {
      await http.put(
        Uri.parse('$baseUrl/deliverables/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': status}),
      );
    } catch (e) {
      debugPrint('Error updating deliverable status: $e');
    }
  }
  
  // Database methods for projects
  static Future<List<Map<String, dynamic>>> getProjects() async {
    try {
      debugPrint('Fetching projects from database via BackendApiService');
      final backendService = BackendApiService();
      final response = await backendService.getProjects();

      if (response.isSuccess && response.data != null) {
        final dynamic raw = response.data;
        final List<dynamic> items = <dynamic>[];

        if (raw is List) {
          items.addAll(raw);
        } else if (raw is Map) {
          final dynamic inner = raw['data'] ?? raw['projects'] ?? raw['items'];
          if (inner is List) {
            items.addAll(inner);
          } else if (inner is Map) {
            items.add(inner);
          }
        }

        final List<Map<String, dynamic>> projects = [];
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            projects.add(Map<String, dynamic>.from(item));
          } else if (item is Map) {
            projects.add(Map<String, dynamic>.from(item.cast<String, dynamic>()));
          }
        }

        debugPrint('✅ Fetched ${projects.length} projects from database');
        return projects;
      }

      debugPrint('❌ Failed to fetch projects: ${response.statusCode} - ${response.error}');
      return [];
    } catch (e) {
      debugPrint('Error fetching projects: $e');
      return [];
    }
  }
  
  // Database methods for sprints
  static Future<List<Map<String, dynamic>>> getSprints({String? projectId, String? projectKey}) async {
    try {
      debugPrint('Fetching sprints from database');
      
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/sprints').replace(queryParameters: {
        'limit': '1000',
        if (projectId != null && projectId.isNotEmpty) 'project_id': projectId,
        if (projectKey != null && projectKey.isNotEmpty) 'project_key': projectKey,
      });
      final response = await http.get(uri, headers: headers);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Fetched ${data['data'].length} sprints from database');
          return List<Map<String, dynamic>>.from(data['data']);
      }
      }
      
      debugPrint('❌ Failed to fetch sprints: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('Error fetching sprints: $e');
      return [];
    }
  }

  // Update sprint status
  static Future<bool> updateSprintStatus(String sprintId, String newStatus) async {
    try {
      debugPrint('Updating sprint $sprintId status to $newStatus');
      
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/sprints/$sprintId'),
        headers: headers,
        body: jsonEncode({'status': newStatus}),
      );
      
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        debugPrint('✅ Sprint status updated successfully');
        return true;
      }
      
      debugPrint('❌ Failed to update sprint status: ${response.statusCode}');
      debugPrint('Error response: ${response.body}');
      return false;
    } catch (e) {
      debugPrint('Error updating sprint status: $e');
      return false;
    }
  }

  // Create a new project
  static Future<Map<String, dynamic>?> createProject({
    required String name,
    required String key,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      debugPrint('Creating project: $name ($key)');
      
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/projects'),
        headers: headers,
        body: jsonEncode({
          'name': name,
          'key': key,
          'description': description ?? '',
          'startDate': startDate?.toIso8601String(),
          'endDate': endDate?.toIso8601String(),
        }),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Project created successfully');
        return data['data'] ?? data;
      }
      
      debugPrint('❌ Failed to create project: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Error creating project: $e');
      return null;
    }
  }
  
  static Future<Map<String, dynamic>?> createSprint({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required int plannedPoints,
    required int completedPoints,
    required String createdBy, required String description, int? committedPoints, int? carriedOverPoints, int? addedDuringSprint, int? removedDuringSprint, int? testPassRate, int? codeCoverage, int? escapedDefects, int? defectsOpened, int? defectsClosed, required String defectSeverityMix, int? codeReviewCompletion, required String documentationStatus, required String uatNotes, int? uatPassRate, int? risksIdentified, int? risksMitigated, required String blockers, required String decisions,
    String? projectId,
  }) async {
    try {
      final backendService = BackendApiService();
      final payload = {
        'name': name,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'plannedPoints': plannedPoints,
        'completedPoints': completedPoints,
        'createdBy': createdBy,
        'description': description,
        'committedPoints': committedPoints,
        'carriedOverPoints': carriedOverPoints,
        'addedDuringSprint': addedDuringSprint,
        'removedDuringSprint': removedDuringSprint,
        'testPassRate': testPassRate,
        'codeCoverage': codeCoverage,
        'escapedDefects': escapedDefects,
        'defectsOpened': defectsOpened,
        'defectsClosed': defectsClosed,
        'defectSeverityMix': defectSeverityMix,
        'codeReviewCompletion': codeReviewCompletion,
        'documentationStatus': documentationStatus,
        'uatNotes': uatNotes,
        'uatPassRate': uatPassRate,
        'risksIdentified': risksIdentified,
        'risksMitigated': risksMitigated,
        'blockers': blockers,
        'decisions': decisions,
        'projectId': projectId,
      }..removeWhere((key, value) => value == null);
      final response = await backendService.createSprint(payload);
      if (response.isSuccess && response.data != null) {
        return Map<String, dynamic>.from(response.data!);
      } else {
        debugPrint('Failed to create sprint: ${response.statusCode} - ${response.error}');
        return null;
      }
    } catch (e) {
      debugPrint('Error creating sprint: $e');
      return null;
    }
  }

  // Sprint metrics methods
  static Future<List<Map<String, dynamic>>> getSprintMetrics(String sprintId) async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.getSprintMetrics(sprintId);

      if (response.isSuccess && response.data != null) {
        final dynamic raw = response.data;
        if (raw is List) {
          return raw.cast<Map<String, dynamic>>();
        }
        final List<dynamic> items = (raw is Map)
            ? (raw['data'] ?? raw['metrics'] ?? [])
            : [];
        return items.cast<Map<String, dynamic>>();
      } else {
        debugPrint('Failed to load sprint metrics: ${response.statusCode} - ${response.error}');
        return [];
      }
    } catch (e) {
      debugPrint('Error loading sprint metrics: $e');
      return [];
    }
  }

  // Sign-off report methods
  static Future<Map<String, dynamic>?> createSignOffReport({
    required String deliverableId,
    required String reportTitle,
    required String reportContent,
    String? sprintPerformanceData,
    String? knownLimitations,
    String? nextSteps,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sign-off-reports'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'deliverable_id': deliverableId,
          'report_title': reportTitle,
          'report_content': reportContent,
          'sprint_performance_data': sprintPerformanceData,
          'known_limitations': knownLimitations,
          'next_steps': nextSteps,
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        debugPrint('Failed to create sign-off report: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error creating sign-off report: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getSignOffReports() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sign-off-reports'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        final List<dynamic> items = (data is Map)
            ? (data['reports'] ?? data['data'] ?? [])
            : [];
        return items.cast<Map<String, dynamic>>();
      } else {
        debugPrint('Failed to load sign-off reports: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error loading sign-off reports: $e');
      return [];
    }
  }

  // Client review methods
  static Future<Map<String, dynamic>?> submitClientReview({
    required String signOffReportId,
    required String reviewStatus,
    String? reviewComments,
    String? changeRequestDetails,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/client-reviews'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sign_off_report_id': signOffReportId,
          'review_status': reviewStatus,
          'review_comments': reviewComments,
          'change_request_details': changeRequestDetails,
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        debugPrint('Failed to submit client review: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error submitting client review: $e');
      return null;
    }
  }

  // Release readiness methods
  static Future<List<Map<String, dynamic>>> getReleaseReadinessChecks(String deliverableId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/deliverables/$deliverableId/readiness-checks'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['checks']);
      } else {
        debugPrint('Failed to load readiness checks: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error loading readiness checks: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> updateReadinessCheck({
    required String checkId,
    required bool isPassed,
    String? checkDetails,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/readiness-checks/$checkId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'is_passed': isPassed,
          'check_details': checkDetails,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('Failed to update readiness check: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error updating readiness check: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> getDashboardData() async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.getDashboardData();
      if (response.isSuccess && response.data != null) {
        final dynamic raw = response.data!;
        if (raw is Map<String, dynamic>) return raw;
        if (raw is List && raw.isNotEmpty) return {'items': raw};
      }
      final sprintsResp = await backendService.getSprints(page: 1, limit: 100);
      final dynamic sprintsRaw = sprintsResp.isSuccess ? sprintsResp.data : null;
      final List<dynamic> sprintsList = sprintsRaw is List
          ? sprintsRaw
          : (sprintsRaw is Map ? (sprintsRaw['data'] ?? sprintsRaw['sprints'] ?? []) : []);
      final List<Map<String, dynamic>> sprints = sprintsList
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      final sprintStats = sprints
          .map(
            (s) => {
              'completed_points': (s['completed_points'] ?? 0) as num,
              'committed_points': (s['committed_points'] ?? 0) as num,
              'test_pass_rate': (s['test_pass_rate'] ?? 0) as num,
            },
          )
          .toList();
      final double avgVelocity = sprintStats.isNotEmpty
          ? sprintStats.map((m) => (m['completed_points'] as num).toDouble()).reduce((a, b) => a + b) / sprintStats.length
          : 0.0;
      final double avgTestPassRate = sprints.isNotEmpty
          ? sprints.map((s) => ((s['test_pass_rate'] ?? 0) as num).toDouble()).reduce((a, b) => a + b) / sprints.length
          : 0.0;
      final trends = sprints.asMap().entries.map((e) {
        final m = e.value;
        final num points = (m['completed_points'] ?? 0) as num;
        final num quality = (m['test_pass_rate'] ?? 0) as num;
        return {
          'week': 'S${e.key + 1}',
          'points': points,
          'quality': quality,
        };
      }).toList();
      int activeUsers = 0;
      try {
        final usersResp = await backendService.getUsers(page: 1, limit: 200);
        final dynamic usersRaw = usersResp.isSuccess ? usersResp.data : null;
        final List<dynamic> usersList = usersRaw is List
            ? usersRaw
            : (usersRaw is Map ? (usersRaw['data'] ?? usersRaw['users'] ?? []) : []);
        activeUsers = usersList.length;
      } catch (_) {}
      int dailyActions = 0;
      try {
        final logsResp = await backendService.getAuditLogs(limit: 100);
        final dynamic logsRaw = logsResp.isSuccess ? logsResp.data : null;
        final List<dynamic> logsList = logsRaw is List
            ? logsRaw
            : (logsRaw is Map ? (logsRaw['audit_logs'] ?? logsRaw['items'] ?? logsRaw['logs'] ?? []) : []);
        dailyActions = logsList.length;
      } catch (_) {}
      return {
        'sprints': sprints,
        'sprint_stats': sprintStats,
        'team_performance': sprints.map(
          (s) => {
            'name': s['name'] ?? 'Sprint',
            'velocity': (s['completed_points'] ?? 0) as num,
            'qualityScore': (s['test_pass_rate'] ?? 0) as num,
            'efficiency': ((s['completed_points'] ?? 0) as num) == 0
                ? 0
                : (((s['completed_points'] ?? 0) as num).toDouble() /
                    (((s['committed_points'] ?? 1) as num).toDouble())) * 100,
          },
        ).toList(),
        'performance_trends': trends,
        'user_activity': {
          'active_users': activeUsers,
          'daily_actions': dailyActions,
          'defect_rate': 0,
          'avg_review_time': 0,
        },
        'metrics': {
          'avg_velocity': avgVelocity,
          'avg_test_pass_rate': avgTestPassRate,
        },
      };
    } catch (e) {
      debugPrint('Error assembling dashboard data: $e');
      return {
        'sprints': [],
        'sprint_stats': [],
        'team_performance': [],
        'performance_trends': [],
        'user_activity': {
          'active_users': 0,
          'daily_actions': 0,
          'defect_rate': 0,
          'avg_review_time': 0,
        },
        'metrics': {
          'avg_velocity': 0,
          'avg_test_pass_rate': 0,
        },
      };
    }
  }

  // Repository file methods
  static Future<List<Map<String, dynamic>>> getProjectFiles(String projectId) async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.listFiles(prefix: projectId);
      
      if (response.isSuccess && response.data != null) {
        final dynamic raw = response.data!;
        final List<dynamic> items = raw is List
            ? raw
            : (raw is Map<String, dynamic>
                ? (raw['data'] ?? raw['files'] ?? raw['items'] ?? [])
                : []);
        final List<Map<String, dynamic>> normalized = [];
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final map = Map<String, dynamic>.from(item);
            final v = map['sizeInMB'];
            double parsed;
            if (v is num) {
              parsed = v.toDouble();
            } else if (v is String) {
              parsed = double.tryParse(v) ?? 0.0;
            } else {
              parsed = 0.0;
            }
            map['sizeInMB'] = parsed;
            normalized.add(map);
          }
        }
        return normalized;
      } else {
        debugPrint('Failed to fetch project files: ${response.statusCode} - ${response.error}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching project files: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> uploadFile({
    required String projectId,
    required String fileName,
    required String fileType,
    required String description,
    required String filePath,
    Uint8List? fileBytes,
  }) async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.uploadFile(filePath, fileName, fileType);
      
      if (response.isSuccess && response.data != null) {
        return response.data!;
      } else {
        debugPrint('Failed to upload file: ${response.statusCode} - ${response.error}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading file: $e');
      return null;
    }
  }

// Tickets
  static Future<Map<String, dynamic>?> createTicket({
    required String sprintId,
    required String title,
    required String description,
    String? assignee,
    required String priority,
    required String type,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'sprintId': sprintId,
        'title': title,
        'description': description,
        'assignee': assignee,
        'priority': priority,
        'type': type,
        'status': 'To Do',
      };
      final response = await http.post(
        Uri.parse('$baseUrl/tickets'),
        headers: headers,
        body: jsonEncode(body),
      );
if (response.statusCode == 200 || response.statusCode == 201) {
        final dynamic raw = jsonDecode(response.body);
        if (raw is Map) {
          final data = raw['data'] ?? raw;
          if (data is Map) return Map<String, dynamic>.from(data);
        }
        return null;
      } else {
        debugPrint('Failed to create ticket: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error creating ticket: $e');
      return null;
    }
  }

  // System metrics methods
  static Future<SystemMetrics> getSystemMetrics() async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.getSystemStats();

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        // Extract system metrics from the stats response with proper type conversion
        final systemMetrics = SystemMetrics(
          systemHealth: SystemHealthStatus.healthy,
          performance: PerformanceMetrics(
                  cpuUsage: _parseDouble(data['system']?['system_usage']?['cpuUsage']) ?? 0.0,
                  memoryUsage: _parseDouble(data['system']?['system_usage']?['memoryUsage']) ?? 0.0,
                  diskUsage: _parseDouble(data['system']?['system_usage']?['diskUsage']) ?? 0.0,
                  responseTime: _parseInt(data['system']?['system_usage']?['responseTime']) ?? 0,
                  uptime: _parseDouble(data['system']?['system_usage']?['uptime']) ?? 0.0,
                ),
          database: DatabaseMetrics(
            totalRecords: _parseInt(data['statistics']?['totalEntities']) ?? 0,
            activeConnections: _parseInt(data['system']?['activeConnections']) ?? 0,
            cacheHitRatio: _parseDouble(data['system']?['cacheHitRatio']) ?? 0.0,
            queryCount: _parseInt(data['system']?['queryCount']) ?? 0,
            slowQueries: _parseInt(data['system']?['slowQueries']) ?? 0,
          ),
          userActivity: UserActivityMetrics(
            activeUsers: _parseInt(data['statistics']?['users']) ?? await _fallbackActiveUsers(),
            totalSessions: _parseInt(data['system']?['totalSessions']) ?? 0,
            newRegistrations: _parseInt(data['system']?['newRegistrations']) ?? 0,
            failedLogins: _parseInt(data['system']?['failedLogins']) ?? 0,
            avgSessionDuration: _parseDouble(data['system']?['avgSessionDuration']) ?? 0.0,
          ),
          lastUpdated: DateTime.now(),
        );
        return systemMetrics;
      } else {
        debugPrint('Failed to load system metrics: ${response.statusCode} - ${response.error}');
        throw Exception('Failed to load system metrics: ${response.statusCode} - ${response.error}');
      }
    } catch (e) {
      debugPrint('Error loading system metrics: $e');
      throw Exception('Error loading system metrics: $e');
    }
  }

  static Future<int> _fallbackActiveUsers() async {
    try {
      final backendService = BackendApiService();
      final resp = await backendService.getUsers(page: 1, limit: 500);
      final dynamic raw = resp.isSuccess ? resp.data : null;
      final List<dynamic> items = raw is List
          ? raw
          : (raw is Map ? (raw['users'] ?? raw['data'] ?? raw['items'] ?? []) : []);
      int count = 0;
      for (final u in items) {
        if (u is Map) {
          final m = Map<String, dynamic>.from(u);
          final active = m['is_active'];
          if (active == true || active == 'true' || active == 1) {
            count++;
          }
        }
      }
      return count > 0 ? count : items.length;
    } catch (_) {
      return 0;
    }
  }

  // Helper methods for type conversion
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static Future<bool> deleteFile(String fileId) async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.deleteFile(fileId);
      
      return response.isSuccess;
    } catch (e) {
      debugPrint('Error deleting file: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.getUsers(page: 1, limit: 200);

      if (response.isSuccess && response.data != null) {
        final dynamic raw = response.data;
        if (raw is List) {
          return raw.cast<Map<String, dynamic>>();
        }
        final List<dynamic> items = (raw is Map)
            ? (raw['data'] ?? raw['users'] ?? raw['items'] ?? [])
            : [];
        return items.cast<Map<String, dynamic>>();
      } else {
        debugPrint('Failed to load users: ${response.statusCode} - ${response.error}');
        return [];
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
      return [];
    }
  }

  // Settings methods
  static Future<Map<String, dynamic>?> getUserSettings() async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.getUserSettings();
      
      if (response.isSuccess && response.data != null) {
        return response.data!;
      } else {
        debugPrint('Failed to fetch user settings: ${response.statusCode} - ${response.error}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching user settings: $e');
      return null;
    }
  }

  static Future<bool> updateUserSettings(Map<String, dynamic> settings) async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.updateUserSettings(settings);
      
      return response.isSuccess;
    } catch (e) {
      debugPrint('Error updating user settings: $e');
      return false;
    }
  }

  static Future<bool> resetUserSettings() async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.resetUserSettings();
      
      return response.isSuccess;
    } catch (e) {
      debugPrint('Error resetting user settings: $e');
      return false;
    }
  }

  static Future<bool> exportUserData() async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.exportUserData();
      
      return response.isSuccess;
    } catch (e) {
      debugPrint('Error exporting user data: $e');
      return false;
    }
  }

  static Future<bool> clearUserCache() async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.clearUserCache();
      
      return response.isSuccess;
    } catch (e) {
      debugPrint('Error clearing user cache: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getSprintTickets(String sprintId) async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.getSprintTickets(sprintId);

      if (response.isSuccess && response.data != null) {
        final dynamic raw = response.data;
        if (raw is List) {
          return raw.cast<Map<String, dynamic>>();
        }
        final List<dynamic> items = (raw is Map)
            ? (raw['data'] ?? raw['tickets'] ?? raw['items'] ?? [])
            : [];
        return items.cast<Map<String, dynamic>>();
      } else {
        debugPrint('Failed to load sprint tickets: ${response.statusCode} - ${response.error}');
        return [];
      }
    } catch (e) {
      debugPrint('Error loading sprint tickets: $e');
      return [];
    }
  }

  // QA-specific methods
  static Future<List<Map<String, dynamic>>> getTestQueue() async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.getTestQueue();

      if (response.isSuccess && response.data != null) {
        final List<dynamic> items = response.data!['data'] ?? response.data!['testQueue'] ?? [];
        return items.cast<Map<String, dynamic>>();
      } else {
        debugPrint('Failed to load test queue: ${response.statusCode} - ${response.error}');
        return [];
      }
    } catch (e) {
      debugPrint('Error loading test queue: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> getQualityMetrics() async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.getQualityMetrics();

      if (response.isSuccess && response.data != null) {
        return response.data! as Map<String, dynamic>;
      } else {
        debugPrint('Failed to load quality metrics: ${response.statusCode} - ${response.error}');
        return {};
      }
    } catch (e) {
      debugPrint('Error loading quality metrics: $e');
      return {};
    }
  }

  static Future<List<Map<String, dynamic>>> getBugReports({int limit = 10}) async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.getBugReports(limit: limit);

      if (response.isSuccess && response.data != null) {
        final List<dynamic> items = response.data!['data'] ?? response.data!['bugReports'] ?? [];
        return items.cast<Map<String, dynamic>>();
      } else {
        debugPrint('Failed to load bug reports: ${response.statusCode} - ${response.error}');
        return [];
      }
    } catch (e) {
      debugPrint('Error loading bug reports: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> getTestCoverage() async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.getTestCoverage();

      if (response.isSuccess && response.data != null) {
        return response.data! as Map<String, dynamic>;
      } else {
        debugPrint('Failed to load test coverage: ${response.statusCode} - ${response.error}');
        return {};
      }
    } catch (e) {
      debugPrint('Error loading test coverage: $e');
      return {};
    }
  }

  // Project management methods
  static Future<Project?> getProject(String projectId) async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.getProject(projectId);

      if (response.isSuccess && response.data != null) {
        return Project.fromJson(response.data!);
      } else {
        debugPrint('Failed to load project: ${response.statusCode} - ${response.error}');
        return null;
      }
    } catch (e) {
      debugPrint('Error loading project: $e');
      return null;
    }
  }

  static Future<List<Project>> getProjectModels() async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.getProjects();

      if (response.isSuccess && response.data != null) {
        final List<dynamic> items = response.data!['data'] ?? response.data!['projects'] ?? [];
        return items.map((item) => Project.fromJson(item)).toList();
      } else {
        debugPrint('Failed to load projects: ${response.statusCode} - ${response.error}');
        return [];
      }
    } catch (e) {
      debugPrint('Error loading projects: $e');
      return [];
    }
  }

  static Future<Project?> createProjectModel(Project project) async {
    try {
      final backendService = BackendApiService();
      final Map<String, dynamic> body = Map<String, dynamic>.from(project.toJson());

      // For project creation, let the backend generate the UUID id
      body.remove('id');

      final response = await backendService.createProject(body);

      Project? createdProject;

      if (response.isSuccess) {
        try {
          final raw = response.data;
          Map<String, dynamic>? created;

          if (raw is Map<String, dynamic>) {
            final body = raw['data'] ?? raw['project'] ?? raw;
            if (body is Map) {
              created = Map<String, dynamic>.from(body);
            }
          } else if (raw is Map) {
            final body = raw['data'] ?? raw['project'] ?? raw;
            if (body is Map) {
              created = Map<String, dynamic>.from(body);
            }
          } else if (raw is List && raw.isNotEmpty) {
            created = Map<String, dynamic>.from(raw.first as Map);
          }

          if (created != null) {
            try {
              createdProject = Project.fromJson(created);
            } catch (e) {
              debugPrint('Error parsing created project into model: $e');
            }

            try {
              final prefs = await SharedPreferences.getInstance();
              final existingStr = prefs.getString('local_created_projects');
              final List<Map<String, dynamic>> existing = (existingStr != null && existingStr.isNotEmpty)
                  ? List<Map<String, dynamic>>.from(jsonDecode(existingStr) as List)
                  : <Map<String, dynamic>>[];
              final createdId = created['id']?.toString();
              if (createdId != null && createdId.isNotEmpty) {
                existing.removeWhere((p) => p['id']?.toString() == createdId);
              }
              existing.insert(0, created);
              await prefs.setString('local_created_projects', jsonEncode(existing));
            } catch (e) {
              debugPrint('Error caching locally created project: $e');
            }
          }
        } catch (e) {
          debugPrint('Error parsing created project response: $e');
        }

        debugPrint('Project created successfully');
        return createdProject;
      } else {
        debugPrint('Failed to create project: ${response.statusCode} - ${response.error}');
        return null;
      }
    } catch (e) {
      debugPrint('Error creating project: $e');
      return null;
    }
  }

  static Future<bool> updateProject(Project project) async {
    try {
      final backendService = BackendApiService();
      final Map<String, dynamic> body = Map<String, dynamic>.from(project.toJson());
      body.remove('id');
      final response = await backendService.updateProject(project.id, body);

      if (response.isSuccess) {
        debugPrint('Project updated successfully');
        return true;
      } else {
        debugPrint('Failed to update project: ${response.statusCode} - ${response.error}');
        return false;
      }
    } catch (e) {
      debugPrint('Error updating project: $e');
      return false;
    }
  }

  static Future<bool> deleteProject(String projectId) async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.deleteProject(projectId);

      if (response.isSuccess) {
        debugPrint('Project deleted successfully');
        return true;
      } else {
        debugPrint('Failed to delete project: ${response.statusCode} - ${response.error}');
        return false;
      }
    } catch (e) {
      debugPrint('Error deleting project: $e');
      return false;
    }
  }

  static Future<bool> addProjectMember(String projectId, ProjectMember member) async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.addProjectMember(projectId, member.toJson());

      if (response.isSuccess) {
        debugPrint('Project member added successfully');
        return true;
      } else {
        debugPrint('Failed to add project member: ${response.statusCode} - ${response.error}');
        return false;
      }
    } catch (e) {
      debugPrint('Error adding project member: $e');
      return false;
    }
  }

  static Future<bool> removeProjectMember(String projectId, String userId) async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.removeProjectMember(projectId, userId);

      if (response.isSuccess) {
        debugPrint('Project member removed successfully');
        return true;
      } else {
        debugPrint('Failed to remove project member: ${response.statusCode} - ${response.error}');
        return false;
      }
    } catch (e) {
      debugPrint('Error removing project member: $e');
      return false;
    }
  }

  static Future<bool> linkDeliverableToProject(String projectId, String deliverableId) async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.linkDeliverableToProject(projectId, deliverableId);

      if (response.isSuccess) {
        debugPrint('Deliverable linked to project successfully');
        return true;
      } else {
        debugPrint('Failed to link deliverable to project: ${response.statusCode} - ${response.error}');
        return false;
      }
    } catch (e) {
      debugPrint('Error linking deliverable to project: $e');
      return false;
    }
  }

  static Future<bool> unlinkDeliverableFromProject(String projectId, String deliverableId) async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.unlinkDeliverableFromProject(projectId, deliverableId);

      if (response.isSuccess) {
        debugPrint('Deliverable unlinked from project successfully');
        return true;
      } else {
        debugPrint('Failed to unlink deliverable from project: ${response.statusCode} - ${response.error}');
        return false;
      }
    } catch (e) {
      debugPrint('Error unlinking deliverable from project: $e');
      return false;
    }
  }

  static Future<bool> associateSprintWithProject(String projectId, List<String> sprintIds) async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.associateSprintWithProject(projectId, sprintIds);

      if (response.isSuccess) {
        debugPrint('Sprint(s) associated with project successfully');
        return true;
      } else {
        debugPrint('Failed to associate sprint(s) with project: ${response.statusCode} - ${response.error}');
        return false;
      }
    } catch (e) {
      debugPrint('Error associating sprint with project: $e');
      return false;
    }
  }

  static Future<bool> dissociateSprintFromProject(String projectId, String sprintId) async {
    try {
      final backendService = BackendApiService();
      final response = await backendService.dissociateSprintFromProject(projectId, sprintId);

      if (response.isSuccess) {
        debugPrint('Sprint dissociated from project successfully');
        return true;
      } else {
        debugPrint('Failed to dissociate sprint from project: ${response.statusCode} - ${response.error}');
        return false;
      }
    } catch (e) {
      debugPrint('Error dissociating sprint from project: $e');
      return false;
    }
  }
}
