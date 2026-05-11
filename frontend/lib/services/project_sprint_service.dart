import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/environment.dart';
import 'auth_service.dart';

class ProjectSprintService {
  static final String _baseUrl = Environment.apiBaseUrl;

  static Future<String?> _getAuthToken() async {
    final authService = AuthService();
    await authService.initialize();
    return authService.accessToken;
  }

  static Future<Map<String, dynamic>> getProjectSprints(String projectId) async {
    try {
      final token = await _getAuthToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/projects/$projectId/sprints'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'projectId': projectId,
            'sprints': data['data'] ?? [],
          };
        }
      }
      throw Exception('Failed to load project sprints');
    } catch (e) {
      throw Exception('Error loading project sprints: $e');
    }
  }

  static Future<Map<String, dynamic>> getAvailableSprints(String projectId) async {
    try {
      final token = await _getAuthToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/projects/$projectId/available-sprints'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }
      throw Exception('Failed to load available sprints');
    } catch (e) {
      throw Exception('Error loading available sprints: $e');
    }
  }

  static Future<Map<String, dynamic>> linkSprintsToProject(String projectId, List<String> sprintIds) async {
    try {
      final token = await _getAuthToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/projects/$projectId/sprints'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'sprintIds': sprintIds}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }
      throw Exception('Failed to link sprints to project');
    } catch (e) {
      throw Exception('Error linking sprints to project: $e');
    }
  }

  static Future<Map<String, dynamic>> createNewSprintForProject(String projectId, Map<String, dynamic> sprintData) async {
    try {
      final token = await _getAuthToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/projects/$projectId/sprints/new'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(sprintData),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }
      throw Exception('Failed to create sprint for project');
    } catch (e) {
      throw Exception('Error creating sprint for project: $e');
    }
  }

  static Future<Map<String, dynamic>> unlinkSprintFromProject(String projectId, String sprintId) async {
    try {
      final token = await _getAuthToken();
      final response = await http.delete(
        Uri.parse('$_baseUrl/projects/$projectId/sprints/$sprintId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }
      throw Exception('Failed to unlink sprint from project');
    } catch (e) {
      throw Exception('Error unlinking sprint from project: $e');
    }
  }

  static String formatSprintStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'completed':
        return 'Completed';
      case 'planned':
        return 'Planned';
      default:
        return status ?? 'Unknown';
    }
  }

  static Color getSprintStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'planned':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  static String formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Not set';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  static double calculateProgress(Map<String, dynamic> sprint) {
    final completedPoints = sprint['completed_points'] ?? 0;
    final totalPoints = sprint['total_points'] ?? 0;
    return totalPoints > 0 ? completedPoints / totalPoints : 0.0;
  }
}
