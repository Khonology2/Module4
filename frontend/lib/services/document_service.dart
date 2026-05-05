import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/repository_file.dart';
import '../services/api_client.dart';
import '../config/environment.dart';
import '../services/auth_service.dart';

// Conditional imports for web download
import 'document_service_stub.dart'
    if (dart.library.html) 'document_service_web.dart' as web_impl;

class DocumentService {
  final AuthService _authService;
final ApiClient _apiClient = ApiClient();
  static final String _baseUrl = Environment.apiBaseUrl;

  DocumentService(this._authService);

  // Get all documents
  Future<ApiResponse> getDocuments({
    String? search,
    String? fileType,
    String? uploader,
    String? projectId,
    String? sprintId,
    String? deliverableId,
    String? from,
    String? to,
  }) async {
    try {
      await _apiClient.initialize();
      final queryParams = <String, String>{
        if (search != null && search.isNotEmpty) 'search': search,
        if (fileType != null && fileType.isNotEmpty) 'fileType': fileType,
        if (uploader != null && uploader.isNotEmpty) 'uploader': uploader,
        if (projectId != null && projectId.isNotEmpty) 'project_id': projectId,
        if (sprintId != null && sprintId.isNotEmpty) 'sprint_id': sprintId,
        if (deliverableId != null && deliverableId.isNotEmpty) 'deliverable_id': deliverableId,
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
      };

      final apiResponse = await _apiClient.get('/documents', queryParams: queryParams);

      if (apiResponse.isSuccess && apiResponse.data != null) {
        final raw = apiResponse.data;
        final List<dynamic> list = (raw is List)
            ? raw
            : (raw is Map<String, dynamic> && raw['data'] is List)
                ? List<dynamic>.from(raw['data'])
                : <dynamic>[];

        final documents = list
            .map((doc) => RepositoryFile.fromJson(Map<String, dynamic>.from(doc)))
            .toList();
        return ApiResponse.success({'documents': documents}, apiResponse.statusCode);
      }

      return ApiResponse.error(apiResponse.error ?? 'Failed to fetch documents', apiResponse.statusCode);
    } catch (e) {
      return ApiResponse.error('Error fetching documents: $e');
    }
  }

  // Get document audit
  Future<ApiResponse> getDocumentAudit(String documentId) async {
    try {
      final token = _authService.accessToken;
      if (token == null) return ApiResponse.error('No access token available');

      final response = await http.get(
        Uri.parse('$_baseUrl/documents/$documentId/audit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return ApiResponse.success({'audit': data['data']}, response.statusCode);
        }
        return ApiResponse.error(data['error'] ?? 'Failed to load audit');
      }
      return ApiResponse.error('Failed to load audit: ${response.statusCode}');
    } catch (e) {
      return ApiResponse.error('Error loading audit: $e');
    }
  }

  // Get repository audit with filters
  Future<ApiResponse> getRepositoryAudit({ String? projectId, String? sprintId, String? deliverableId, String? from, String? to }) async {
    try {
      final token = _authService.accessToken;
      if (token == null) return ApiResponse.error('No access token available');

      final uri = Uri.parse('$_baseUrl/repository/audit').replace(
        queryParameters: {
          if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
          if (sprintId != null && sprintId.isNotEmpty) 'sprintId': sprintId,
          if (deliverableId != null && deliverableId.isNotEmpty) 'deliverableId': deliverableId,
          if (from != null && from.isNotEmpty) 'from': from,
          if (to != null && to.isNotEmpty) 'to': to,
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return ApiResponse.success({'audit': data['data']}, response.statusCode);
        }
        return ApiResponse.error(data['error'] ?? 'Failed to load repository audit');
      }
      return ApiResponse.error('Failed to load repository audit: ${response.statusCode}');
    } catch (e) {
      return ApiResponse.error('Error loading repository audit: $e');
    }
  }

  // Upload a document
  Future<ApiResponse> uploadDocument({
    required String filePath,
    String? description,
    String? tags,
    String? projectId,
    String? projectKey,
    String? sprintId,
    String? deliverableId,
  }) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('No access token available');
      }

      final file = File(filePath);
      if (!await file.exists()) {
        return ApiResponse.error('File does not exist');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/files/upload'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      if (description != null && description.isNotEmpty) {
        request.fields['description'] = description;
      }
      if (tags != null && tags.isNotEmpty) {
        request.fields['tags'] = tags;
      }
      if (projectId != null && projectId.trim().isNotEmpty) {
        request.fields['project_id'] = projectId.trim();
      }
      if (projectKey != null && projectKey.trim().isNotEmpty) {
        request.fields['project_key'] = projectKey.trim();
      }
      if (sprintId != null && sprintId.trim().isNotEmpty) {
        request.fields['sprint_id'] = sprintId.trim();
      }
      if (deliverableId != null && deliverableId.trim().isNotEmpty) {
        request.fields['deliverable_id'] = deliverableId.trim();
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final raw = jsonDecode(response.body);
        final mapped = {
          'id': raw['filename']?.toString() ?? '',
          'name': raw['title']?.toString() ?? raw['originalName']?.toString() ?? raw['filename']?.toString() ?? 'Uploaded File',
          'fileType': (raw['filename']?.toString() ?? '').split('.').last,
          'uploaded_at': DateTime.now().toIso8601String(),
          'uploaded_by': raw['uploadedBy']?.toString() ?? _authService.currentUser?.id.toString() ?? 'system',
          'size': raw['size']?.toString(),
          'description': description ?? '',
          'uploader': raw['uploadedBy']?.toString() ?? _authService.currentUser?.id.toString() ?? 'system',
          'size_in_mb': ((raw['size'] ?? 0) as num) / (1024 * 1024),
          'file_path': raw['url'],
          'tags': tags,
          'uploader_name': raw['uploaderName']?.toString() ?? _authService.currentUser?.name ?? 'System',
        };
        final document = RepositoryFile.fromJson(mapped);
        return ApiResponse.success({'document': document}, response.statusCode);
      } else {
        final errorBody = response.body;
        try {
          final errorData = jsonDecode(errorBody);
          final errorMessage = errorData['error'] ?? 'Failed to upload document';
          final errorDetails = errorData['details'];
          return ApiResponse.error(
            errorDetails != null ? '$errorMessage: $errorDetails' : '$errorMessage: ${response.statusCode}',
          );
        } catch (_) {
          return ApiResponse.error('Failed to upload document: ${response.statusCode}');
        }
      }
    } catch (e) {
      return ApiResponse.error('Error uploading document: $e');
    }
  }

  // Upload document for web
  Future<ApiResponse> uploadWebDocument({
    required List<int> fileBytes,
    required String fileName,
    String? description,
    String? tags,
    String? projectId,
    String? projectKey,
    String? sprintId,
    String? deliverableId,
  }) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('No access token available');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/files/upload'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      // Don't set Content-Type manually - let http library set it with boundary

      // Add file bytes
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
      ),);

      // Add optional fields
      if (description != null && description.isNotEmpty) {
        request.fields['description'] = description;
      }
      if (tags != null && tags.isNotEmpty) {
        request.fields['tags'] = tags;
      }
      if (projectId != null && projectId.trim().isNotEmpty) {
        request.fields['project_id'] = projectId.trim();
      }
      if (projectKey != null && projectKey.trim().isNotEmpty) {
        request.fields['project_key'] = projectKey.trim();
      }
      if (sprintId != null && sprintId.trim().isNotEmpty) {
        request.fields['sprint_id'] = sprintId.trim();
      }
      if (deliverableId != null && deliverableId.trim().isNotEmpty) {
        request.fields['deliverable_id'] = deliverableId.trim();
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final raw = jsonDecode(response.body);
        final mapped = {
          'id': raw['filename']?.toString() ?? '',
          'name': raw['title']?.toString() ?? raw['originalName']?.toString() ?? fileName,
          'fileType': (fileName).split('.').last,
          'uploaded_at': DateTime.now().toIso8601String(),
          'uploaded_by': raw['uploadedBy']?.toString() ?? _authService.currentUser?.id.toString() ?? 'system',
          'size': raw['size']?.toString(),
          'description': description ?? '',
          'uploader': raw['uploadedBy']?.toString() ?? _authService.currentUser?.id.toString() ?? 'system',
          'size_in_mb': ((raw['size'] ?? 0) as num) / (1024 * 1024),
          'file_path': raw['url'],
          'tags': tags,
          'uploader_name': raw['uploaderName']?.toString() ?? _authService.currentUser?.name ?? 'System',
        };
        final document = RepositoryFile.fromJson(mapped);
        return ApiResponse.success({'document': document}, response.statusCode);
      } else {
        final errorBody = response.body;
        try {
          final errorData = jsonDecode(errorBody);
          final errorMessage = errorData['error'] ?? 'Failed to upload document';
          final errorDetails = errorData['details'];
          return ApiResponse.error(
            errorDetails != null ? '$errorMessage: $errorDetails' : '$errorMessage: ${response.statusCode}',
          );
        } catch (_) {
          return ApiResponse.error('Failed to upload document: ${response.statusCode}');
        }
      }
    } catch (e) {
      return ApiResponse.error('Error uploading document: $e');
    }
  }

  // Download a document
  Future<ApiResponse> downloadDocument(String documentId) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('No authentication token available');
      }

      // For web platform, handle download differently
      if (kIsWeb) {
        return _downloadDocumentWeb(documentId, token);
      }

      // Request permission to write to storage (mobile/desktop only)
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        return ApiResponse.error('Storage permission denied');
      }

      // Get document details first
      final detailsResponse = await http.get(
        Uri.parse('$_baseUrl/documents/$documentId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (detailsResponse.statusCode != 200) {
        return ApiResponse.error('Failed to get document details');
      }

      final detailsData = jsonDecode(detailsResponse.body);
      if (!detailsData['success']) {
        return ApiResponse.error('Failed to get document details: ${detailsData['error']}');
      }

      final document = detailsData['data'];
      final fileName = document['name'] ?? 'document_$documentId';

      // Download the file
      final response = await http.get(
        Uri.parse('$_baseUrl/documents/$documentId/download'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        // Get the downloads directory
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        return ApiResponse.success({
          'filePath': file.path,
          'fileName': fileName,
          'size': response.bodyBytes.length,
        }, response.statusCode,);
      } else {
        return ApiResponse.error('Failed to download document: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResponse.error('Error downloading document: $e');
    }
  }

  // Web-specific download method
  Future<ApiResponse> _downloadDocumentWeb(String documentId, String token) async {
    try {
      // Get document details first to get the filename
      final detailsResponse = await http.get(
        Uri.parse('$_baseUrl/documents/$documentId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      String fileName = 'document_$documentId';
      if (detailsResponse.statusCode == 200) {
        final detailsData = jsonDecode(detailsResponse.body);
        if (detailsData['success'] && detailsData['data']['name'] != null) {
          fileName = detailsData['data']['name'];
        }
      }

      final uri = Uri.parse('$_baseUrl/documents/$documentId/download');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // For web, create a blob and trigger download
        if (kIsWeb) {
          _triggerWebDownload(response.bodyBytes, fileName);
        }

        return ApiResponse.success({
          'filePath': 'Downloaded to browser',
          'fileName': fileName,
          'size': response.bodyBytes.length,
        }, response.statusCode,);
      } else {
        return ApiResponse.error('Failed to download document: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResponse.error('Error downloading document: $e');
    }
  }

  // Web-specific download helper (uses dart:html only on web)
  void _triggerWebDownload(List<int> bytes, String fileName) {
    if (kIsWeb) {
      web_impl.triggerWebDownloadImpl(bytes, fileName);
    }
  }

  // Delete a document
  Future<ApiResponse> deleteDocument(String documentId) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('No access token available');
      }

      final response = await http.delete(
        Uri.parse('$_baseUrl/documents/$documentId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return ApiResponse.success({'message': 'Document deleted successfully'}, response.statusCode);
        } else {
          return ApiResponse.error(data['error'] ?? 'Failed to delete document');
        }
      } else {
        return ApiResponse.error('Failed to delete document: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResponse.error('Error deleting document: $e');
    }
  }

  // Track document view
  Future<ApiResponse> trackDocumentView(String documentId) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/documents/$documentId/view'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return ApiResponse.success(<String, dynamic>{}, response.statusCode);
      } else {
        final data = jsonDecode(response.body);
        return ApiResponse.error(data['error'] ?? 'Failed to track view');
      }
    } catch (e) {
      return ApiResponse.error('Error tracking view: $e');
    }
  }

  // Get document preview
  Future<ApiResponse> getDocumentPreview(String documentId) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        return ApiResponse.error('No access token available');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/documents/$documentId/preview'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return ApiResponse.success(data['data'], response.statusCode);
        } else {
          return ApiResponse.error(data['error'] ?? 'Failed to get document preview');
        }
      } else {
        return ApiResponse.error('Failed to get document preview: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResponse.error('Error getting document preview: $e');
    }
  }
}
