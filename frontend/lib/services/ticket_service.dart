import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/environment.dart';

class Ticket {
  final String ticketId;
  final String ticketKey;
  final String summary;
  final String? description;
  final String issueType;
  final String priority;
  final String? assignee;
  final String reporter;
  final String? projectId;
  final String? sprintId;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;

  Ticket({
    required this.ticketId,
    required this.ticketKey,
    required this.summary,
    this.description,
    required this.issueType,
    required this.priority,
    this.assignee,
    required this.reporter,
    this.projectId,
    this.sprintId,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      ticketId: json['ticket_id'] ?? '',
      ticketKey: json['ticket_key'] ?? '',
      summary: json['summary'] ?? '',
      description: json['description'],
      issueType: json['issue_type'] ?? 'Task',
      priority: json['priority'] ?? 'Medium',
      assignee: json['assignee'],
      reporter: json['reporter'] ?? '',
      projectId: json['project_id'],
      sprintId: json['sprint_id'],
      userId: json['user_id'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
      status: json['status'] ?? 'To Do',
    );
  }
}

class Epic {
  final String epicId;
  final String epicKey;
  final String name;
  final String? description;
  final String color;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? ticketCount;

  Epic({
    required this.epicId,
    required this.epicKey,
    required this.name,
    this.description,
    required this.color,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.ticketCount,
  });

  factory Epic.fromJson(Map<String, dynamic> json) {
    return Epic(
      epicId: json['id'] ?? '',
      epicKey: json['epic_key'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      color: json['color'] ?? '#6F42C1',
      createdBy: json['created_by'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
      ticketCount: json['ticket_count'] ?? 0,
    );
  }
}

class TicketService {
  static Future<List<Ticket>> getTickets({
    String? projectId,
    String? sprintId,
    String? status,
    String? assignee,
  }) async {
    try {
      final response = await _makeRequest(
        'GET',
        '/api/v1/tickets${_buildQueryString({
          'project_id': projectId,
          'sprint_id': sprintId,
          'status': status,
          'assignee': assignee,
        })}',
      );

      if (response['success'] == true) {
        final List<dynamic> ticketsData = response['data'];
        return ticketsData.map((ticket) => Ticket.fromJson(ticket)).toList();
      } else {
        throw Exception(response['error'] ?? 'Failed to fetch tickets');
      }
    } catch (e) {
      throw Exception('Failed to fetch tickets: $e');
    }
  }

  static Future<Ticket> createTicket({
    required String summary,
    String? description,
    String issueType = 'Task',
    String priority = 'Medium',
    String? assignee,
    required String projectId,
    String? sprintId,
    String? ticketKey,
  }) async {
    try {
      final response = await _makeRequest(
        'POST',
        '/api/v1/tickets',
        body: {
          'summary': summary,
          'description': description,
          'issue_type': issueType,
          'priority': priority,
          'assignee': assignee,
          'project_id': projectId,
          'sprint_id': sprintId,
          'ticket_key': ticketKey,
        },
      );

      if (response['success'] == true) {
        return Ticket.fromJson(response['data']);
      } else {
        throw Exception(response['error'] ?? 'Failed to create ticket');
      }
    } catch (e) {
      throw Exception('Failed to create ticket: $e');
    }
  }

  static Future<Ticket> updateTicketStatus({
    required String ticketId,
    required String status,
  }) async {
    try {
      final response = await _makeRequest(
        'PUT',
        '/api/v1/tickets/$ticketId',
        body: {
          'status': status,
        },
      );

      if (response['success'] == true) {
        return Ticket.fromJson(response['data']);
      } else {
        throw Exception(response['error'] ?? 'Failed to update ticket');
      }
    } catch (e) {
      throw Exception('Failed to update ticket: $e');
    }
  }

  static Future<List<Epic>> getEpics() async {
    try {
      final response = await _makeRequest('GET', '/api/v1/epics');

      if (response['success'] == true) {
        final List<dynamic> epicsData = response['data'];
        return epicsData.map((epic) => Epic.fromJson(epic)).toList();
      } else {
        throw Exception(response['error'] ?? 'Failed to fetch epics');
      }
    } catch (e) {
      throw Exception('Failed to fetch epics: $e');
    }
  }

  static Future<Epic> createEpic({
    required String name,
    String? description,
    String color = '#6F42C1',
    String? epicKey,
  }) async {
    try {
      final response = await _makeRequest(
        'POST',
        '/api/v1/epics',
        body: {
          'name': name,
          'description': description,
          'color': color,
          'epic_key': epicKey,
        },
      );

      if (response['success'] == true) {
        return Epic.fromJson(response['data']);
      } else {
        throw Exception(response['error'] ?? 'Failed to create epic');
      }
    } catch (e) {
      throw Exception('Failed to create epic: $e');
    }
  }

  static Future<void> linkEpicToSprint({
    required String epicKey,
    required String sprintId,
  }) async {
    try {
      final response = await _makeRequest(
        'POST',
        '/api/v1/epics/$epicKey/sprints/$sprintId',
      );

      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Failed to link epic to sprint');
      }
    } catch (e) {
      throw Exception('Failed to link epic to sprint: $e');
    }
  }

  static Future<List<Ticket>> getBacklog({String? projectId}) async {
    try {
      final response = await _makeRequest(
        'GET',
        '/api/v1/backlog${_buildQueryString({'project_id': projectId})}',
      );

      if (response['success'] == true) {
        final List<dynamic> ticketsData = response['data'];
        return ticketsData.map((ticket) => Ticket.fromJson(ticket)).toList();
      } else {
        throw Exception(response['error'] ?? 'Failed to fetch backlog');
      }
    } catch (e) {
      throw Exception('Failed to fetch backlog: $e');
    }
  }

  static String _buildQueryString(Map<String, String?> params) {
    if (params.isEmpty) return '';
    
    final queryString = params.entries
        .where((entry) => entry.value != null && entry.value!.isNotEmpty)
        .map((entry) => '${entry.key}=${Uri.encodeComponent(entry.value!)}')
        .join('&');
    
    return queryString.isNotEmpty ? '?$queryString' : '';
  }

  static Future<Map<String, dynamic>> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final url = '${Environment.apiBaseUrl}$endpoint';
    
    try {
      final response = await _makeHttpRequest(method, url, body: body);
      
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<http.Response> _makeHttpRequest(String method, String url, {Map<String, dynamic>? body}) async {
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body != null ? jsonEncode(body) : null,
      );
      
      return response;
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
