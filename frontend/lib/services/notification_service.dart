import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/notification_item.dart';
import '../config/environment.dart';

class NotificationService {
  static final String _baseUrl = Environment.apiBaseUrl;
  String? _authToken;

  void setAuthToken(String token) {
    _authToken = token;
  }

  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      if (_authToken != null) 'Authorization': 'Bearer $_authToken',
    };
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/notifications/count'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data']['unreadCount'] ?? 0;
        }
      }
      return 0;
    } catch (e) {
      debugPrint('Error fetching unread count: $e');
      return 0;
    }
  }

  Future<List<NotificationItem>> getNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/notifications/me'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data
              .map((json) =>
                  NotificationItem.fromJson(json as Map<String, dynamic>))
              .toList();
        } else if (data is Map && data['data'] is List) {
          return (data['data'] as List)
              .map((json) =>
                  NotificationItem.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return [];
    }
  }

  Future<bool> markAsRead(String notificationId) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/notifications/$notificationId/read'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return false;
    }
  }

  Future<bool> markAllAsRead() async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/notifications/read-all'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      return false;
    }
  }

  Future<bool> createNotification({
    required String title,
    required String message,
    required NotificationType type,
    String? userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/notifications'),
        headers: _headers,
        body: json.encode({
          'title': title,
          'message': message,
          'type': type.name,
          'user_id': userId,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error creating notification: $e');
      return false;
    }
  }

  Future<bool> notifySprintStatusChange({
    required String sprintName,
    required String oldStatus,
    required String newStatus,
    required String changedBy,
  }) async {
    const title = 'Sprint Status Changed';
    final message =
        '$changedBy changed "$sprintName" status from $oldStatus to $newStatus';
    return await createNotification(
      title: title,
      message: message,
      type: NotificationType.sprint,
    );
  }

  Future<bool> notifySprintCreated({
    required String sprintName,
    required String projectName,
    required String createdBy,
  }) async {
    const title = 'New Sprint Created';
    final message =
        '$createdBy created sprint "$sprintName" in project "$projectName"';
    return await createNotification(
      title: title,
      message: message,
      type: NotificationType.sprint,
    );
  }

  Future<bool> notifyTicketCreated({
    required String ticketTitle,
    required String sprintName,
    required String createdBy,
  }) async {
    const title = 'New Ticket Created';
    final message =
        '$createdBy created ticket "$ticketTitle" in sprint "$sprintName"';
    return await createNotification(
      title: title,
      message: message,
      type: NotificationType.sprint,
    );
  }

  Future<bool> notifyTicketMoved({
    required String ticketTitle,
    required String sprintName,
    required String oldStatus,
    required String newStatus,
    required String movedBy,
  }) async {
    const title = 'Ticket Moved';
    final message =
        '$movedBy moved ticket "$ticketTitle" from $oldStatus to $newStatus in sprint "$sprintName"';
    return await createNotification(
      title: title,
      message: message,
      type: NotificationType.sprint,
    );
  }

  Future<bool> notifyProjectCreated({
    required String projectName,
    required String createdBy,
  }) async {
    const title = 'New Project Created';
    final message = '$createdBy created new project "$projectName"';
    return await createNotification(
      title: title,
      message: message,
      type: NotificationType.system,
    );
  }

  // Enhanced synchronization methods
  Future<bool> broadcastNotification({
    required List<String> recipients,
    required List<String> roles,
    required String message,
    required String title,
    NotificationType type = NotificationType.system,
    Map<String, dynamic>? payload,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/notifications/broadcast'),
        headers: _headers,
        body: json.encode({
          'recipients': recipients,
          'roles': roles,
          'message': message,
          'title': title,
          'type': type.name,
          'payload': payload ?? {},
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      debugPrint('Error broadcasting notification: $e');
      return false;
    }
  }

  Future<bool> syncNotifications() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/notifications/sync'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error syncing notifications: $e');
      return false;
    }
  }

  Future<List<NotificationItem>> getUnreadNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/notifications/me?unread_only=true'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data
              .map((json) =>
                  NotificationItem.fromJson(json as Map<String, dynamic>))
              .toList();
        } else if (data is Map && data['data'] is List) {
          return (data['data'] as List)
              .map((json) =>
                  NotificationItem.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching unread notifications: $e');
      return [];
    }
  }
}
