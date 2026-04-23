import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/deliverable.dart';

class DeliverableService {
  final ApiClient _apiClient = ApiClient();
  final AuthService _authService = AuthService();

  Future<ApiResponse> getDeliverablesForSprint(String sprintId) async {
    try {
      if (sprintId.trim().isEmpty) {
        return ApiResponse.error('Sprint ID is required');
      }

      final response = await _apiClient.get('/deliverables/sprint/$sprintId');

      if (response.isSuccess && response.data != null) {
        List<dynamic> deliverablesJson = [];

        if (response.data is List) {
          deliverablesJson = response.data as List<dynamic>;
        } else if (response.data is Map) {
          final data = response.data as Map<String, dynamic>;
          deliverablesJson =
              data['data'] as List<dynamic>? ?? data['deliverables'] as List<dynamic>? ?? [];
        }

        final List<Deliverable> deliverables = deliverablesJson
            .map((json) {
              try {
                return Deliverable.fromJson(json as Map<String, dynamic>);
              } catch (e) {
                debugPrint('Error parsing deliverable: $e, json: $json');
                return null;
              }
            })
            .whereType<Deliverable>()
            .toList();

        return ApiResponse.success({'deliverables': deliverables}, response.statusCode);
      }

      return ApiResponse.error(response.error ?? 'Failed to fetch sprint deliverables');
    } catch (e, stackTrace) {
      debugPrint('Exception in getDeliverablesForSprint: $e');
      debugPrint('Stack trace: $stackTrace');
      return ApiResponse.error('Error fetching sprint deliverables: $e');
    }
  }

  // Get all deliverables
  Future<ApiResponse> getDeliverables({String? projectId}) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('No access token available');
      }

      final queryParams = <String, String>{};
      if (projectId != null && projectId.isNotEmpty) {
        queryParams['project_id'] = projectId;
      }

      final response = await _apiClient.get('/deliverables', queryParams: queryParams);
      
      if (response.isSuccess && response.data != null) {
        try {
          // Handle different response structures
          List<dynamic> deliverablesJson = [];
          
          if (response.data is List) {
            // Direct list
            deliverablesJson = response.data as List<dynamic>;
          } else if (response.data is Map) {
            // Nested in 'data' or 'deliverables' key
            final data = response.data as Map<String, dynamic>;
            deliverablesJson = data['data'] as List<dynamic>? ?? 
                              data['deliverables'] as List<dynamic>? ?? 
                              [];
          }
          
          final List<Deliverable> deliverables = deliverablesJson
              .map((json) {
                try {
                  return Deliverable.fromJson(json as Map<String, dynamic>);
                } catch (e) {
                  debugPrint('Error parsing deliverable: $e, json: $json');
                  return null;
                }
              })
              .whereType<Deliverable>()
              .toList();
          
          try {
            await _saveCachedDeliverables(deliverables);
          } catch (_) {}
          return ApiResponse.success({'deliverables': deliverables}, response.statusCode);
        } catch (e) {
          debugPrint('Error processing deliverables response: $e');
          debugPrint('Response data type: ${response.data.runtimeType}');
          debugPrint('Response data: ${response.data}');
          return ApiResponse.error('Error processing deliverables: $e');
        }
      } else {
        final cached = await _getCachedDeliverables();
        if (cached.isNotEmpty) {
          return ApiResponse.success({'deliverables': cached}, response.statusCode);
        }
        return ApiResponse.error(response.error ?? 'Failed to fetch deliverables');
      }
    } catch (e, stackTrace) {
      debugPrint('Exception in getDeliverables: $e');
      debugPrint('Stack trace: $stackTrace');
      final cached = await _getCachedDeliverables();
      if (cached.isNotEmpty) {
        return ApiResponse.success({'deliverables': cached}, 200);
      }
      return ApiResponse.error('Error fetching deliverables: $e');
    }
  }

  // Get a single deliverable by ID
  Future<ApiResponse> getDeliverable(String id) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('No access token available');
      }

      final response = await _apiClient.get('/deliverables/$id');
      
      if (response.isSuccess && response.data != null) {
        try {
          Map<String, dynamic> deliverableJson;
          
          if (response.data is Map<String, dynamic>) {
            deliverableJson = response.data as Map<String, dynamic>;
          } else if (response.data is Map) {
            deliverableJson = Map<String, dynamic>.from(response.data as Map);
          } else {
            return ApiResponse.error('Unexpected response format: ${response.data.runtimeType}');
          }
          
          final deliverable = Deliverable.fromJson(deliverableJson);
          return ApiResponse.success({'deliverable': deliverable}, response.statusCode);
        } catch (e) {
          return ApiResponse.error('Error parsing deliverable: $e');
        }
      } else {
        return ApiResponse.error(response.error ?? 'Failed to fetch deliverable');
      }
    } catch (e) {
      return ApiResponse.error('Error fetching deliverable: $e');
    }
  }

  // Create a new deliverable
  Future<ApiResponse> createDeliverable({
    required String title,
    String? description,
    List<DoDItem>? definitionOfDone,
    String priority = 'Medium',
    String status = 'Draft',
    DateTime? dueDate,
    String? assignedTo,
    String? sprintId,
    List<String>? sprintIds,
    List<String>? evidenceLinks,
    String? ownerId,
    String? projectId,
  }) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        debugPrint('No access token available, proceeding without Authorization header');
      }

      // Convert Definition of Done to a JSON string for backend TEXT column
      String? dodString;
      if (definitionOfDone != null) {
         dodString = jsonEncode(definitionOfDone.map((e) => e.toJson()).toList());
      }

      final body = {
        'title': title,
        'description': description,
        'definition_of_done': dodString,
        'priority': priority,
        'status': status,
        'due_date': dueDate?.toIso8601String(),
        'created_by': _authService.currentUser?.id,
        'assigned_to': assignedTo,
        if ((sprintIds != null && sprintIds.isNotEmpty) || (sprintId != null && sprintId.trim().isNotEmpty))
          'sprintIds': (sprintIds != null && sprintIds.isNotEmpty)
              ? sprintIds
              : [sprintId!.trim()],
        if (evidenceLinks != null) 'evidence_links': evidenceLinks,
        if (ownerId != null) 'owner_id': ownerId,
        if (projectId != null) 'project_id': projectId,
      };

      final response = await _apiClient.post('/deliverables', body: body);
      
      if (response.isSuccess && response.data != null) {
        try {
          // ApiClient already extracts the 'data' field from backend response
          // So response.data should be the deliverable object directly
          Map<String, dynamic> deliverableJson;
          
          if (response.data is Map<String, dynamic>) {
            deliverableJson = response.data as Map<String, dynamic>;
          } else if (response.data is Map) {
            deliverableJson = Map<String, dynamic>.from(response.data as Map);
          } else {
            debugPrint('❌ Unexpected response data type: ${response.data.runtimeType}');
            debugPrint('📦 Response data: ${response.data}');
            return ApiResponse.error('Unexpected response format: ${response.data.runtimeType}');
          }
          
          if (deliverableJson.isEmpty) {
            return ApiResponse.error('Deliverable data is empty');
          }
          
          debugPrint('📦 Parsing deliverable from JSON: ${deliverableJson.keys}');
          final deliverable = Deliverable.fromJson(deliverableJson);
          try { await _prependCachedDeliverable(deliverable); } catch (_) {}
          return ApiResponse.success({'deliverable': deliverable}, response.statusCode);
        } catch (e, stackTrace) {
          debugPrint('❌ Error parsing deliverable response: $e');
          debugPrint('📚 Stack trace: $stackTrace');
          debugPrint('📦 Response data: ${response.data}');
          debugPrint('📦 Response data type: ${response.data.runtimeType}');
          return ApiResponse.error('Error parsing deliverable: $e');
        }
      } else {
        debugPrint('❌ Deliverable creation failed: ${response.error}');
        debugPrint('📦 Response status: ${response.statusCode}');
        return ApiResponse.error(response.error ?? 'Failed to create deliverable');
      }
    } catch (e) {
      return ApiResponse.error('Error creating deliverable: $e');
    }
  }

  // Upload an artifact for a deliverable
  Future<ApiResponse> uploadArtifact({
    required String deliverableId,
    required String filePath,
    required String fileName,
    String? title,
    String? description,
    List<int>? fileBytes,
  }) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('No access token available');
      }

      final fileType = fileName.contains('.') ? fileName.split('.').last : 'file';
      
      final fields = <String, String>{};
      if (title != null) fields['title'] = title;
      if (description != null) fields['description'] = description;

      ApiResponse response;
      if (fileBytes != null && fileBytes.isNotEmpty) {
        response = await _apiClient.uploadFileBytes(
          '/deliverables/$deliverableId/artifacts',
          fileBytes: fileBytes,
          filename: fileName,
          fields: fields,
        );
      } else if (!kIsWeb && filePath.trim().isNotEmpty) {
        response = await _apiClient.uploadFile(
          '/deliverables/$deliverableId/artifacts',
          filePath,
          fileName,
          fileType,
          fields: fields,
        );
      } else {
        return ApiResponse.error('No file data provided. Please reselect the file.');
      }

      if (response.isSuccess) {
         return response;
      } else {
        return ApiResponse.error(response.error ?? 'Failed to upload artifact');
      }
    } catch (e) {
      return ApiResponse.error('Error uploading artifact: $e');
    }
  }

  Future<ApiResponse> deleteArtifact(String deliverableId, String artifactId) async {
    return await _apiClient.delete('/deliverables/$deliverableId/artifacts/$artifactId');
  }

  // ===== Local cache helpers =====
  static const String _deliverablesKey = 'cached_deliverables';

  static Future<void> _saveCachedDeliverables(List<Deliverable> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = list.map((d) => d.toJson()).toList();
      await prefs.setString(_deliverablesKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('❌ Error caching deliverables: $e');
    }
  }

  static Future<List<Deliverable>> _getCachedDeliverables() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_deliverablesKey);
      if (s != null && s.isNotEmpty) {
        final list = jsonDecode(s);
        if (list is List) {
          return list.map((e) => Deliverable.fromJson(Map<String, dynamic>.from(e))).toList();
        }
      }
    } catch (e) {
      debugPrint('❌ Error reading cached deliverables: $e');
    }
    return [];
  }

  static Future<void> _prependCachedDeliverable(Deliverable d) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_deliverablesKey);
      final list = (s != null && s.isNotEmpty)
          ? List<Map<String, dynamic>>.from(jsonDecode(s))
          : <Map<String, dynamic>>[];
      list.insert(0, d.toJson());
      await prefs.setString(_deliverablesKey, jsonEncode(list));
    } catch (e) {
      debugPrint('❌ Error updating cached deliverables: $e');
    }
  }

  // Update a deliverable
  Future<ApiResponse> updateDeliverable({
    required String id,
    String? title,
    String? description,
    List<DoDItem>? definitionOfDone,
    String? priority,
    String? status,
    DateTime? dueDate,
    String? assignedTo,
    List<String>? sprintIds,
    List<String>? evidenceLinks,
    String? ownerId,
    String? projectId,
  }) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('No access token available');
      }

      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (definitionOfDone != null) body['definition_of_done'] = jsonEncode(definitionOfDone.map((e) => e.toJson()).toList());
      if (priority != null) body['priority'] = priority;
      if (status != null) body['status'] = status;
      if (dueDate != null) body['due_date'] = dueDate.toIso8601String();
      if (assignedTo != null) body['assigned_to'] = assignedTo;
      if (sprintIds != null) body['sprintIds'] = sprintIds;
      if (evidenceLinks != null) body['evidence_links'] = evidenceLinks;
      if (ownerId != null) body['owner_id'] = ownerId;
      if (projectId != null) body['project_id'] = projectId;

      final response = await _apiClient.put('/deliverables/$id', body: body);
      
      if (response.isSuccess && response.data != null) {
        try {
          // ApiClient already extracts the 'data' field from backend response
          Map<String, dynamic> deliverableJson;
          
          if (response.data is Map<String, dynamic>) {
            deliverableJson = response.data as Map<String, dynamic>;
          } else if (response.data is Map) {
            deliverableJson = Map<String, dynamic>.from(response.data as Map);
          } else {
            return ApiResponse.error('Unexpected response format: ${response.data.runtimeType}');
          }
          
          final deliverable = Deliverable.fromJson(deliverableJson);
          return ApiResponse.success({'deliverable': deliverable}, response.statusCode);
        } catch (e) {
          return ApiResponse.error('Error parsing deliverable: $e');
        }
      } else {
        return ApiResponse.error(response.error ?? 'Failed to update deliverable');
      }
    } catch (e) {
      return ApiResponse.error('Error updating deliverable: $e');
    }
  }

  // Delete a deliverable
  Future<ApiResponse> deleteDeliverable(String id) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('No access token available');
      }

      final response = await _apiClient.delete('/deliverables/$id');
      if (response.isSuccess) {
        return response;
      } else {
        return ApiResponse.error(response.error ?? 'Failed to delete deliverable');
      }
    } catch (e) {
      return ApiResponse.error('Error deleting deliverable: $e');
    }
  }

  // Update deliverable status
  Future<ApiResponse> updateDeliverableStatus(String id, String status) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('No access token available');
      }

      // Map enum name to backend expected format
      String normalizedStatus = status;
      if (status == 'inProgress') normalizedStatus = 'in_progress';
      if (status == 'inReview') normalizedStatus = 'in_review';
      if (status == 'signedOff') normalizedStatus = 'signed_off';
      if (status == 'changeRequested') normalizedStatus = 'change_requested';

      final response = await _apiClient.put(
        '/deliverables/$id/updateStatus',
        body: {'status': normalizedStatus},
      );

      if (response.isSuccess && response.data != null) {
        try {
          // ApiClient already extracts the 'data' field from backend response
          Map<String, dynamic> deliverableJson;
          
          if (response.data is Map<String, dynamic>) {
            deliverableJson = response.data as Map<String, dynamic>;
          } else if (response.data is Map) {
            deliverableJson = Map<String, dynamic>.from(response.data as Map);
          } else {
            return ApiResponse.error('Unexpected response format: ${response.data.runtimeType}');
          }
          
          final deliverable = Deliverable.fromJson(deliverableJson);
          return ApiResponse.success({'deliverable': deliverable}, response.statusCode);
        } catch (e) {
          return ApiResponse.error('Error parsing deliverable: $e');
        }
      } else {
        return ApiResponse.error(response.error ?? 'Failed to update deliverable status');
      }
    } catch (e) {
      return ApiResponse.error('Error updating deliverable status: $e');
    }
  }

  // Get deliverables by status
  Future<ApiResponse> getDeliverablesByStatus(String status) async {
    try {
      final response = await getDeliverables();
      if (response.isSuccess && response.data != null) {
        final List<Deliverable> allDeliverables = response.data!['deliverables'] as List<Deliverable>;
        final List<Deliverable> filteredDeliverables = allDeliverables
            .where((deliverable) => deliverable.status.name.toLowerCase() == status.toLowerCase())
            .toList();
        
        return ApiResponse.success({'deliverables': filteredDeliverables}, 200);
      } else {
        return response;
      }
    } catch (e) {
      return ApiResponse.error('Error filtering deliverables: $e');
    }
  }

  // Get deliverables by priority
  Future<ApiResponse> getDeliverablesByPriority(String priority) async {
    try {
      final response = await getDeliverables();
      if (response.isSuccess && response.data != null) {
        final List<Deliverable> allDeliverables = response.data!['deliverables'] as List<Deliverable>;
        final List<Deliverable> filteredDeliverables = allDeliverables
            .where((deliverable) => deliverable.priority.toLowerCase() == priority.toLowerCase())
            .toList();
        
        return ApiResponse.success({'deliverables': filteredDeliverables}, 200);
      } else {
        return response;
      }
    } catch (e) {
      return ApiResponse.error('Error filtering deliverables: $e');
    }
  }
}
