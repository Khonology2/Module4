import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/timeline_event.dart';
import '../config/environment.dart';
import 'auth_service.dart';

class TimelineSyncService {
  static final TimelineSyncService _instance = TimelineSyncService._internal();
  factory TimelineSyncService() => _instance;
  TimelineSyncService._internal();

  final String _baseUrl = Environment.apiBaseUrl;
  DateTime? _lastSyncTime;

  // Helper method to get auth token
  Future<String?> _getAuthToken() async {
    final authService = AuthService();
    await authService.initialize();
    return authService.accessToken;
  }

  // Sync all timeline events from backend
  Future<List<TimelineEvent>> syncTimelineEvents({DateTime? since, bool includeCompleted = false}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        debugPrint('TimelineSync: No auth token available');
        return [];
      }

      // Use active endpoint by default to filter completed projects
      String url;
      if (includeCompleted) {
        // Use sync/all endpoint when we want completed items
        url = '$_baseUrl/timeline/sync/all';
        if (since != null) {
          url += '?last_sync=${since.toIso8601String()}&include_completed=true';
        }
      } else {
        // Use active endpoint to get only active items
        url = '$_baseUrl/timeline/active';
        if (since != null) {
          url += '?start_date=${since.toIso8601String()}';
        }
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> eventsJson = data['data'];
          final events = eventsJson
              .map((json) => _parseTimelineEventFromApi(json))
              .where((event) => event != null)
              .cast<TimelineEvent>()
              .toList();

          // Update last sync time
          if (data['last_sync'] != null) {
            _lastSyncTime = DateTime.parse(data['last_sync']);
          }

          debugPrint('TimelineSync: Successfully synced ${events.length} events (completed: $includeCompleted)');
          return events;
        }
      }

      debugPrint('TimelineSync: API response failed - ${response.statusCode}');
      return [];

    } catch (e) {
      debugPrint('TimelineSync: Error syncing timeline events - $e');
      return [];
    }
  }

  // Get timeline events for a specific project
  Future<List<TimelineEvent>> getProjectTimelineEvents(String projectId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        debugPrint('TimelineSync: No auth token available');
        return [];
      }

      String url = '$_baseUrl/timeline/project/$projectId';
      final Map<String, String> queryParams = {};

      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String();
      }

      if (queryParams.isNotEmpty) {
        final queryString = queryParams.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
            .join('&');
        url += '?$queryString';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> eventsJson = data['data'];
          final events = eventsJson
              .map((json) => _parseTimelineEventFromApi(json))
              .where((event) => event != null)
              .cast<TimelineEvent>()
              .toList();

          debugPrint('TimelineSync: Got ${events.length} events for project $projectId');
          return events;
        }
      }

      debugPrint('TimelineSync: Project timeline API failed - ${response.statusCode}');
      return [];

    } catch (e) {
      debugPrint('TimelineSync: Error getting project timeline - $e');
      return [];
    }
  }

  // Create a new timeline event
  Future<bool> createTimelineEvent({
    required String title,
    required String description,
    required TimelineEventType type,
    required DateTime startTime,
    DateTime? endTime,
    String? projectId,
    String? sprintId,
    String priority = 'medium',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        debugPrint('TimelineSync: No auth token available');
        return false;
      }

      final authService = AuthService();
      final userId = authService.currentUser?.id;

      final eventData = {
        'entity_type': type.name,
        'entity_id': projectId ?? sprintId ?? '',
        'title': title,
        'description': description,
        'start_date': startTime.toIso8601String(),
        'end_date': endTime?.toIso8601String(),
        'created_by': userId,
        'status': 'active',
        'priority': priority,
        'tags': [],
        'metadata': metadata ?? {},
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/timeline'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(eventData),
      );

      if (response.statusCode == 201) {
        debugPrint('TimelineSync: Successfully created timeline event');
        return true;
      }

      debugPrint('TimelineSync: Failed to create event - ${response.statusCode}');
      return false;

    } catch (e) {
      debugPrint('TimelineSync: Error creating timeline event - $e');
      return false;
    }
  }

  // Parse timeline event from API response
  TimelineEvent? _parseTimelineEventFromApi(Map<String, dynamic> json) {
    try {
      // Parse type string to TimelineEventType enum
      TimelineEventType type;
      final typeString = json['type']?.toString().toLowerCase();
      switch (typeString) {
        case 'milestone':
          type = TimelineEventType.milestone;
          break;
        case 'task':
          type = TimelineEventType.task;
          break;
        case 'meeting':
          type = TimelineEventType.meeting;
          break;
        case 'deliverable':
          type = TimelineEventType.deliverable;
          break;
        case 'review':
          type = TimelineEventType.review;
          break;
        case 'deployment':
          type = TimelineEventType.deployment;
          break;
        case 'project':
          type = TimelineEventType.milestone; // Map projects to milestones
          break;
        case 'sprint':
          type = TimelineEventType.task; // Map sprints to tasks
          break;
        default:
          type = TimelineEventType.other;
      }

      // Parse dates
      DateTime? parsedDate, parsedStartTime, parsedEndTime;
      
      if (json['date'] != null) {
        try {
          parsedDate = DateTime.parse(json['date'].toString());
        } catch (e) {
          debugPrint('TimelineSync: Failed to parse date ${json['date']}: $e');
        }
      }
      
      if (json['startTime'] != null) {
        try {
          parsedStartTime = DateTime.parse(json['startTime'].toString());
        } catch (e) {
          debugPrint('TimelineSync: Failed to parse startTime ${json['startTime']}: $e');
        }
      }
      
      if (json['endTime'] != null) {
        try {
          parsedEndTime = DateTime.parse(json['endTime'].toString());
        } catch (e) {
          debugPrint('TimelineSync: Failed to parse endTime ${json['endTime']}: $e');
        }
      }

      return TimelineEvent(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        type: type,
        date: parsedDate,
        startTime: parsedStartTime,
        endTime: parsedEndTime,
        projectId: json['projectId']?.toString(),
        sprintId: json['sprintId']?.toString(),
        deliverableId: json['deliverableId']?.toString(),
        assignedTo: json['assignedTo']?.toString(),
        createdBy: json['createdBy']?.toString(),
        createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'].toString()) : DateTime.now(),
        updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'].toString()) : null,
        metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
        isCompleted: json['isCompleted'] ?? false,
        // Legacy fields
        time: json['time']?.toString(),
        priority: json['priority']?.toString(),
        project: json['project']?.toString(),
        colorTag: json['colorTag']?.toString(),
      );
    } catch (e) {
      debugPrint('TimelineSync: Error parsing timeline event - $e');
      return null;
    }
  }

  // Get last sync time
  DateTime? get lastSyncTime => _lastSyncTime;

  // Check if sync is needed
  bool needsSync() {
    if (_lastSyncTime == null) return true;
    // Sync if last sync was more than 5 minutes ago
    return DateTime.now().difference(_lastSyncTime!) > const Duration(minutes: 5);
  }
}
