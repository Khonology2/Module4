import 'package:flutter/foundation.dart';
import '../models/epic.dart';
import 'api_client.dart';
import 'auth_service.dart';

class EpicService {
  final ApiClient _apiClient = ApiClient();
  final AuthService _authService = AuthService();

  /// Get all epics
  Future<ApiResponse> getEpics({String? projectId, String? status}) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('No access token available');
      }

      final queryParams = <String, String>{};
      if (projectId != null) queryParams['project_id'] = projectId;
      if (status != null) queryParams['status'] = status;

      final response = await _apiClient.get('/epics', queryParams: queryParams);

      if (response.isSuccess && response.data != null) {
        try {
          List<dynamic> epicsJson = [];

          if (response.data is List) {
            epicsJson = response.data as List<dynamic>;
          } else if (response.data is Map) {
            final data = response.data as Map<String, dynamic>;
            epicsJson = data['data'] as List<dynamic>? ??
                data['epics'] as List<dynamic>? ??
                [];
          }

          final List<Epic> epics = epicsJson
              .map((json) {
                try {
                  return Epic.fromJson(json as Map<String, dynamic>);
                } catch (e) {
                  debugPrint('Error parsing epic: $e, json: $json');
                  return null;
                }
              })
              .whereType<Epic>()
              .toList();

          return ApiResponse.success({'epics': epics}, response.statusCode);
        } catch (e) {
          debugPrint('Error processing epics response: $e');
          return ApiResponse.error('Error processing epics: $e');
        }
      } else {
        return ApiResponse.error(response.error ?? 'Failed to fetch epics');
      }
    } catch (e) {
      debugPrint('Exception in getEpics: $e');
      return ApiResponse.error('Error fetching epics: $e');
    }
  }

  /// Get a single epic by ID
  Future<ApiResponse> getEpic(String epicId) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('No access token available');
      }

      final response = await _apiClient.get('/epics/$epicId');

      if (response.isSuccess && response.data != null) {
        try {
          Map<String, dynamic> epicJson;

          if (response.data is Map<String, dynamic>) {
            epicJson = response.data as Map<String, dynamic>;
            // Check if nested in 'data' key
            if (epicJson.containsKey('data') && epicJson['data'] is Map) {
              epicJson = epicJson['data'] as Map<String, dynamic>;
            }
          } else {
            return ApiResponse.error('Unexpected response format');
          }

          final epic = Epic.fromJson(epicJson);
          return ApiResponse.success({'epic': epic}, response.statusCode);
        } catch (e) {
          debugPrint('Error parsing epic: $e');
          return ApiResponse.error('Error parsing epic: $e');
        }
      } else {
        return ApiResponse.error(response.error ?? 'Failed to fetch epic');
      }
    } catch (e) {
      return ApiResponse.error('Error fetching epic: $e');
    }
  }

  /// Create a new epic
  Future<ApiResponse> createEpic({
    required String title,
    String? description,
    String? projectId,
    List<String>? sprintIds,
    List<String>? deliverableIds,
    DateTime? startDate,
    DateTime? targetDate,
  }) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('No access token available');
      }

      final body = {
        'title': title,
        'description': description,
        'project_id': projectId,
        'sprint_ids': sprintIds ?? [],
        'deliverable_ids': deliverableIds ?? [],
        'start_date': startDate?.toIso8601String(),
        'target_date': targetDate?.toIso8601String(),
        'status': 'draft',
      };

      final response = await _apiClient.post('/epics', body: body);

      if (response.isSuccess && response.data != null) {
        try {
          Map<String, dynamic> epicJson;

          if (response.data is Map<String, dynamic>) {
            epicJson = response.data as Map<String, dynamic>;
          } else if (response.data is Map) {
            epicJson = Map<String, dynamic>.from(response.data as Map);
          } else {
            return ApiResponse.error('Unexpected response format');
          }

          final epic = Epic.fromJson(epicJson);
          return ApiResponse.success({'epic': epic}, response.statusCode);
        } catch (e) {
          debugPrint('Error parsing created epic: $e');
          return ApiResponse.error('Error parsing epic: $e');
        }
      } else {
        return ApiResponse.error(response.error ?? 'Failed to create epic');
      }
    } catch (e) {
      return ApiResponse.error('Error creating epic: $e');
    }
  }

  /// Update an epic
  Future<ApiResponse> updateEpic({
    required String id,
    String? title,
    String? description,
    String? status,
    String? projectId,
    List<String>? sprintIds,
    List<String>? deliverableIds,
    DateTime? startDate,
    DateTime? targetDate,
  }) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('No access token available');
      }

      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (status != null) body['status'] = status;
      if (projectId != null) body['project_id'] = projectId;
      if (sprintIds != null) body['sprint_ids'] = sprintIds;
      if (deliverableIds != null) body['deliverable_ids'] = deliverableIds;
      if (startDate != null) body['start_date'] = startDate.toIso8601String();
      if (targetDate != null) body['target_date'] = targetDate.toIso8601String();

      final response = await _apiClient.put('/epics/$id', body: body);

      if (response.isSuccess && response.data != null) {
        try {
          Map<String, dynamic> epicJson;

          if (response.data is Map<String, dynamic>) {
            epicJson = response.data as Map<String, dynamic>;
          } else if (response.data is Map) {
            epicJson = Map<String, dynamic>.from(response.data as Map);
          } else {
            return ApiResponse.error('Unexpected response format');
          }

          final epic = Epic.fromJson(epicJson);
          return ApiResponse.success({'epic': epic}, response.statusCode);
        } catch (e) {
          return ApiResponse.error('Error parsing epic: $e');
        }
      } else {
        return ApiResponse.error(response.error ?? 'Failed to update epic');
      }
    } catch (e) {
      return ApiResponse.error('Error updating epic: $e');
    }
  }

  /// Delete an epic
  Future<ApiResponse> deleteEpic(String id) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('No access token available');
      }

      final response = await _apiClient.delete('/epics/$id');

      if (response.isSuccess) {
        return ApiResponse.success({'message': 'Epic deleted successfully'}, response.statusCode);
      } else {
        return ApiResponse.error(response.error ?? 'Failed to delete epic');
      }
    } catch (e) {
      return ApiResponse.error('Error deleting epic: $e');
    }
  }

  /// Link a sprint to an epic
  Future<ApiResponse> linkSprint(String epicId, String sprintId) async {
    try {
      final response = await _apiClient.post('/epics/$epicId/sprints', body: {
        'sprint_id': sprintId,
      });

      if (response.isSuccess) {
        return ApiResponse.success({'message': 'Sprint linked successfully'}, response.statusCode);
      } else {
        return ApiResponse.error(response.error ?? 'Failed to link sprint');
      }
    } catch (e) {
      return ApiResponse.error('Error linking sprint: $e');
    }
  }

  /// Unlink a sprint from an epic
  Future<ApiResponse> unlinkSprint(String epicId, String sprintId) async {
    try {
      final response = await _apiClient.delete('/epics/$epicId/sprints/$sprintId');

      if (response.isSuccess) {
        return ApiResponse.success({'message': 'Sprint unlinked successfully'}, response.statusCode);
      } else {
        return ApiResponse.error(response.error ?? 'Failed to unlink sprint');
      }
    } catch (e) {
      return ApiResponse.error('Error unlinking sprint: $e');
    }
  }

  /// Link a deliverable to an epic
  Future<ApiResponse> linkDeliverable(String epicId, String deliverableId) async {
    try {
      final response = await _apiClient.post('/epics/$epicId/deliverables', body: {
        'deliverable_id': deliverableId,
      });

      if (response.isSuccess) {
        return ApiResponse.success({'message': 'Deliverable linked successfully'}, response.statusCode);
      } else {
        return ApiResponse.error(response.error ?? 'Failed to link deliverable');
      }
    } catch (e) {
      return ApiResponse.error('Error linking deliverable: $e');
    }
  }

  /// Unlink a deliverable from an epic
  Future<ApiResponse> unlinkDeliverable(String epicId, String deliverableId) async {
    try {
      final response = await _apiClient.delete('/epics/$epicId/deliverables/$deliverableId');

      if (response.isSuccess) {
        return ApiResponse.success({'message': 'Deliverable unlinked successfully'}, response.statusCode);
      } else {
        return ApiResponse.error(response.error ?? 'Failed to unlink deliverable');
      }
    } catch (e) {
      return ApiResponse.error('Error unlinking deliverable: $e');
    }
  }
}
