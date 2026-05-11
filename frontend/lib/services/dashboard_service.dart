import '../models/deliverable.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'deliverable_service.dart';

class DashboardData {
  final List<Deliverable> myDeliverables;
  final List<ActivityItem> recentActivity;
  final DashboardStats stats;

  DashboardData({
    required this.myDeliverables,
    required this.recentActivity,
    required this.stats,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final deliverables = (json['deliverables'] as List)
        .map((item) => Deliverable.fromJson(item))
        .toList();
    
    final activities = (json['recentActivity'] as List)
        .map((item) => ActivityItem.fromJson(item))
        .toList();
    
    final stats = DashboardStats.fromJson(json['statistics']);
    
    return DashboardData(
      myDeliverables: deliverables,
      recentActivity: activities,
      stats: stats,
    );
  }
}

class ActivityItem {
  final String id;
  final String type;
  final String title;
  final String description;
  final String? deliverableTitle;
  final String? sprintName;
  final DateTime createdAt;
  final String createdByName;
  final String? actionUrl;

  ActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.deliverableTitle,
    this.sprintName,
    required this.createdAt,
    required this.createdByName,
    this.actionUrl,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    // Handle activity_description which can be a Map (JSONB) or String
    String description = '';
    final descValue = json['activity_description'];
    if (descValue != null) {
      if (descValue is Map) {
        description = descValue.toString();
      } else if (descValue is String) {
        description = descValue;
      } else {
        description = descValue.toString();
      }
    }
    
    return ActivityItem(
      id: json['id']?.toString() ?? '',
      type: json['activity_type']?.toString() ?? 'activity',
      title: json['activity_title']?.toString() ?? 'Activity',
      description: description,
      deliverableTitle: json['deliverable_title']?.toString(),
      sprintName: json['sprint_name']?.toString(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'].toString()) 
          : DateTime.now(),
      createdByName: json['user_name']?.toString() ?? 'System',
      actionUrl: json['action_url']?.toString(),
    );
  }
}

class DashboardStats {
  final int totalDeliverables;
  final int completedDeliverables;
  final int inProgressDeliverables;
  final int overdueDeliverables;
  final int pendingDeliverables;
  final int unreadNotifications;
  final double completionRate;
  final double avgSignoffDays;
  // Sign-off report statistics
  final int totalReports;
  final int draftReports;
  final int submittedReports;
  final int approvedReports;
  final int changeRequestedReports;

  DashboardStats({
    required this.totalDeliverables,
    required this.completedDeliverables,
    required this.inProgressDeliverables,
    required this.overdueDeliverables,
    required this.pendingDeliverables,
    required this.unreadNotifications,
    required this.completionRate,
    required this.avgSignoffDays,
    required this.totalReports,
    required this.draftReports,
    required this.submittedReports,
    required this.approvedReports,
    required this.changeRequestedReports,
  });

  int get calculatedPendingDeliverables {
    final p = totalDeliverables - completedDeliverables - inProgressDeliverables;
    return p < 0 ? 0 : p;
  }

  String get avgSignoffDaysDisplay => 'N/A';

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    // Safely parse integers from potential string values
    int parseIntSafe(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }
    
    // Safely parse doubles from potential string values
    double parseDoubleSafe(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }
    
    final total = parseIntSafe(json['total_deliverables']);
    final completed = parseIntSafe(json['completed']);
    final inProgress = parseIntSafe(json['in_progress']);
    final avgProgress = parseDoubleSafe(json['avg_progress']);
    final pending = parseIntSafe(json['pending']);
    final avgSignoffDays = parseDoubleSafe(json['avg_signoff_days']);
    
    // Parse sign-off report statistics
    final totalReports = parseIntSafe(json['total_reports']);
    final draftReports = parseIntSafe(json['draft_reports']);
    final submittedReports = parseIntSafe(json['submitted_reports']);
    final approvedReports = parseIntSafe(json['approved_reports']);
    final changeRequestedReports = parseIntSafe(json['change_requested_reports']);
    
    return DashboardStats(
      totalDeliverables: total,
      completedDeliverables: completed,
      inProgressDeliverables: inProgress,
      overdueDeliverables: 0, // Not provided by API yet
      pendingDeliverables: pending,
      unreadNotifications: 0, // Not provided by API yet
      completionRate: avgProgress,
      avgSignoffDays: avgSignoffDays,
      totalReports: totalReports,
      draftReports: draftReports,
      submittedReports: submittedReports,
      approvedReports: approvedReports,
      changeRequestedReports: changeRequestedReports,
    );
  }
}

extension DashboardStatsX on DashboardStats {
  String get avgSignoffDaysDisplay {
    if (avgSignoffDays <= 0) return '—';
    return '${avgSignoffDays.toStringAsFixed(1)} days';
  }
}

class DashboardService {
  final ApiClient _apiClient = ApiClient();
  final AuthService _authService = AuthService();
  final DeliverableService _deliverableService = DeliverableService();

  // Get comprehensive dashboard data
  Future<ApiResponse> getDashboardData() async {
    try {
      final response = await _apiClient.get('/dashboard');
      
      if (response.isSuccess && response.data != null) {
        final dashboardData = DashboardData.fromJson(response.data!);
        return ApiResponse.success({'dashboard': dashboardData}, response.statusCode);
      } else {
        return ApiResponse.error('Failed to load dashboard data');
      }
    } catch (e) {
      return ApiResponse.error('Error fetching dashboard data: $e');
    }
  }



  // Get deliverables with progress tracking
  Future<ApiResponse> getDeliverablesWithProgress() async {
    try {
      final response = await _deliverableService.getDeliverables();
      
      if (response.isSuccess && response.data != null) {
        final List<Deliverable> deliverables = response.data!['deliverables'] as List<Deliverable>;
        final userId = _authService.currentUser?.id;
        
        // Filter and add progress data
        final myDeliverables = deliverables.where((deliverable) {
          return deliverable.assignedTo == userId || deliverable.createdBy == userId;
        }).map((deliverable) {
          return _addProgressData(deliverable);
        }).toList();
        
        return ApiResponse.success({'deliverables': myDeliverables}, 200);
      } else {
        return ApiResponse.error(response.error ?? 'Failed to fetch deliverables');
      }
    } catch (e) {
      return ApiResponse.error('Error fetching deliverables with progress: $e');
    }
  }

  // Add progress calculation to deliverable
  Deliverable _addProgressData(Deliverable deliverable) {
    // Calculate progress based on status
    // Progress calculation logic can be added here if needed
    // For now, we return the deliverable as-is
    return deliverable;
  }

  // Create activity when deliverable is created/updated
  Future<ApiResponse> createActivity({
    required String type,
    required String title,
    required String description,
    String? deliverableId,
    String? sprintId,
  }) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('No access token available');
      }

      final body = {
        'title': title,
        'message': description,
        'type': type,
        'deliverable_id': deliverableId,
        'sprint_id': sprintId,
        'priority': 'normal',
      };

      final response = await _apiClient.post('/notifications/enhanced', body: body);
      
      if (response.isSuccess) {
        return ApiResponse.success({'message': 'Activity created successfully'}, response.statusCode);
      } else {
        return ApiResponse.error(response.error ?? 'Failed to create activity');
      }
    } catch (e) {
      return ApiResponse.error('Error creating activity: $e');
    }
  }

  // Get deliverable progress over time
  Future<ApiResponse> getDeliverableProgress(String deliverableId) async {
    try {
      // This would typically fetch from a progress tracking table
      // For now, we'll return mock data
      final progressData = {
        'deliverable_id': deliverableId,
        'progress_history': [
          {'date': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(), 'progress': 0.0},
          {'date': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'progress': 0.2},
          {'date': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'progress': 0.5},
          {'date': DateTime.now().toIso8601String(), 'progress': 0.8},
        ],
      };
      
      return ApiResponse.success(progressData, 200);
    } catch (e) {
      return ApiResponse.error('Error fetching deliverable progress: $e');
    }
  }
}
