import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/project.dart';
import '../config/environment.dart';
import 'auth_service.dart';

class ProjectService {
  static final String _baseUrl = Environment.apiBaseUrl;

  // Helper method to get auth token
  static Future<String?> _getAuthToken() async {
    final authService = AuthService();
    await authService.initialize();
    return authService.accessToken;
  }

  static Future<List<Project>> getAllProjects({int skip = 0, int limit = 100}) async {
    try {
      final token = await _getAuthToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/projects?skip=$skip&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> projectsJson = data['data'];
          return projectsJson.map((json) => Project.fromJson(json)).toList();
        }
      }
      
      // If API fails or returns no projects, return mock data for testing
      return _getMockProjects();
    } catch (e) {
      debugPrint('Error loading projects from API: $e');
      // Return mock data as fallback
      return _getMockProjects();
    }
  }

  // Mock data for testing purposes
  static List<Project> _getMockProjects() {
    return [
      Project(
        id: 'c93009f3-0e7a-4272-9327-afcfa68ba503', // Real project ID from API
        name: 'ACPS Project',
        key: 'ACPS',
        description: 'Advanced Customer Portal System - A comprehensive customer management platform with real-time analytics and reporting capabilities.',
        clientName: 'ACPS Corporation',
        status: ProjectStatus.active,
        priority: ProjectPriority.high,
        projectType: 'web',
        startDate: DateTime(2024, 1, 15),
        endDate: DateTime(2024, 6, 30),
        createdAt: DateTime(2024, 1, 10),
        updatedAt: DateTime(2024, 1, 20),
        createdBy: 'system',
        members: [
          ProjectMember(
            userId: 'user-001',
            userName: 'John Smith',
            userEmail: 'john.smith@company.com',
            role: ProjectRole.owner,
            assignedAt: DateTime(2024, 1, 10),
          ),
          ProjectMember(
            userId: 'user-002',
            userName: 'Sarah Johnson',
            userEmail: 'sarah.j@company.com',
            role: ProjectRole.contributor,
            assignedAt: DateTime(2024, 1, 12),
          ),
          ProjectMember(
            userId: 'user-003',
            userName: 'Mike Wilson',
            userEmail: 'mike.w@company.com',
            role: ProjectRole.viewer,
            assignedAt: DateTime(2024, 1, 15),
          ),
        ],
      ),
      Project(
        id: 'corner-bus-002',
        name: 'Corner Bus Project',
        key: 'CBUS',
        description: 'Public transportation management system for corner bus routes with real-time tracking and passenger analytics.',
        clientName: 'City Transit Authority',
        status: ProjectStatus.active,
        priority: ProjectPriority.medium,
        projectType: 'mobile',
        startDate: DateTime(2024, 2, 1),
        endDate: DateTime(2024, 8, 31),
        createdAt: DateTime(2024, 1, 25),
        updatedAt: DateTime(2024, 2, 5),
        createdBy: 'system',
        members: [
          ProjectMember(
            userId: 'user-004',
            userName: 'Emily Davis',
            userEmail: 'emily.d@company.com',
            role: ProjectRole.owner,
            assignedAt: DateTime(2024, 1, 25),
          ),
          ProjectMember(
            userId: 'user-005',
            userName: 'Robert Chen',
            userEmail: 'robert.c@company.com',
            role: ProjectRole.contributor,
            assignedAt: DateTime(2024, 2, 1),
          ),
          ProjectMember(
            userId: 'user-006',
            userName: 'Lisa Anderson',
            userEmail: 'lisa.a@company.com',
            role: ProjectRole.contributor,
            assignedAt: DateTime(2024, 2, 3),
          ),
        ],
      ),
    ];
  }

  static Future<Project?> getProjectById(String id) async {
    try {
      debugPrint('ProjectService: Looking for project with ID: $id');
      final token = await _getAuthToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/projects/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return Project.fromJson(data['data']);
        }
      }
      
      // If API fails, try to find in mock data
      debugPrint('ProjectService: API failed, trying mock data...');
      final mockProjects = _getMockProjects();
      debugPrint('ProjectService: Available mock projects: ${mockProjects.map((p) => '${p.name} (${p.id})').toList()}');
      try {
        final foundProject = mockProjects.firstWhere((project) => project.id == id);
        debugPrint('ProjectService: Found project in mock data: ${foundProject.name}');
        return foundProject;
      } catch (e) {
        debugPrint('ProjectService: Project not found in mock data: $e');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching project from API: $e');
      // Try to find in mock data as fallback
      final mockProjects = _getMockProjects();
      try {
        final foundProject = mockProjects.firstWhere((project) => project.id == id);
        debugPrint('ProjectService: Found project in mock data (fallback): ${foundProject.name}');
        return foundProject;
      } catch (e) {
        debugPrint('ProjectService: Project not found in mock data (fallback): $e');
        return null;
      }
    }
  }

  static Future<Project> createProject(Map<String, dynamic> projectData) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/projects'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getAuthToken()}',
        },
        body: json.encode(projectData),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return Project.fromJson(data['data']);
        }
      }
      
      final Map<String, dynamic> errorData = json.decode(response.body);
      throw Exception(errorData['error'] ?? 'Failed to create project');
    } catch (e) {
      throw Exception('Error creating project: $e');
    }
  }

  static Future<Project> updateProject(String id, Map<String, dynamic> projectData) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/projects/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getAuthToken()}',
        },
        body: json.encode(projectData),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return Project.fromJson(data['data']);
        }
      }
      
      final Map<String, dynamic> errorData = json.decode(response.body);
      throw Exception(errorData['error'] ?? 'Failed to update project');
    } catch (e) {
      throw Exception('Error updating project: $e');
    }
  }

  static Future<bool> deleteProject(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/projects/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getAuthToken()}',
        },
      );

      return response.statusCode == 204;
    } catch (e) {
      throw Exception('Error deleting project: $e');
    }
  }

  static String formatProjectStatus(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.planning:
        return 'Planning';
      case ProjectStatus.active:
        return 'Active';
      case ProjectStatus.onHold:
        return 'On Hold';
      case ProjectStatus.completed:
        return 'Completed';
      case ProjectStatus.cancelled:
        return 'Cancelled';
    }
  }

  static String formatProjectPriority(ProjectPriority priority) {
    switch (priority) {
      case ProjectPriority.low:
        return 'Low';
      case ProjectPriority.medium:
        return 'Medium';
      case ProjectPriority.high:
        return 'High';
      case ProjectPriority.critical:
        return 'Critical';
    }
  }

  static String formatDate(DateTime? date) {
    if (date == null) return 'Not set';
    return '${date.day}/${date.month}/${date.year}';
  }

  static String formatFullDate(DateTime? date) {
    if (date == null) return 'Not set';
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  static bool isProjectOverdue(Project project) {
    if (project.endDate == null) return false;
    return DateTime.now().isAfter(project.endDate!) && project.status != ProjectStatus.completed;
  }

  static int getDaysUntilEnd(Project project) {
    if (project.endDate == null) return -1;
    return project.endDate!.difference(DateTime.now()).inDays;
  }

  static double calculateProgress(Project project) {
    // This is a placeholder for progress calculation
    // In a real implementation, this would be based on deliverables, tasks, etc.
    if (project.status == ProjectStatus.completed) return 100.0;
    if (project.status == ProjectStatus.cancelled) return 0.0;
    
    // Simple progress based on status
    switch (project.status) {
      case ProjectStatus.planning:
        return 10.0;
      case ProjectStatus.active:
        return 50.0;
      case ProjectStatus.onHold:
        return 25.0;
      case ProjectStatus.completed:
        return 100.0;
      case ProjectStatus.cancelled:
        return 0.0;
    }
  }
}
