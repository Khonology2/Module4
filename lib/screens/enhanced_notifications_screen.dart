import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_item.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../services/realtime_service.dart';
import '../theme/flownet_theme.dart';
import '../widgets/app_scaffold.dart';
import 'notification_detail_screen.dart';

class EnhancedNotificationsScreen extends ConsumerStatefulWidget {
  const EnhancedNotificationsScreen({super.key});

  @override
  ConsumerState<EnhancedNotificationsScreen> createState() =>
      _EnhancedNotificationsScreenState();
}

class _EnhancedNotificationsScreenState
    extends ConsumerState<EnhancedNotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final AuthService _authService = AuthService();
  final RealtimeService _realtime = RealtimeService();
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  late Function(dynamic) _notificationListener;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    // Initialize realtime service with auth token
    final token = _authService.accessToken;
    if (token != null) {
      _realtime.initialize(authToken: token);
    }

    _notificationListener = (data) {
      if (_disposed) return;

      debugPrint('🔔 Notification screen received: $data');

      // Handle new notifications
      if (data is Map && (data['id'] != null || data['notification'] != null)) {
        _loadNotifications(); // Refresh the list
      }

      // Handle notification count updates
      if (data is Map && data['unreadCount'] != null) {
        // This will be handled by the NotificationCenterWidget
        return;
      }
    };

    _realtime.on('notification_received', _notificationListener);
    _realtime.on('notifications_updated', _notificationListener);
  }

  Future<void> _loadNotifications() async {
    try {
      final token = _authService.accessToken;
      if (token != null) {
        _notificationService.setAuthToken(token);
      }

      final notifications = await _notificationService.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _realtime.off('notification_received', _notificationListener);
    _realtime.off('notifications_updated', _notificationListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppScaffold(
        useBackgroundImage: true,
        centered: false,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return AppScaffold(
      useBackgroundImage: true,
      centered: false,
      scrollable: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read, color: Colors.white),
            onPressed: _markAllAsRead,
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCards(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                return _buildNotificationCard(_notifications[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: (notification.isRead
              ? FlownetColors.graphiteGray
              : FlownetColors.slate)
          .withAlpha((0.65 * 255).toInt()),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getNotificationTypeColor(notification.type),
          child: Icon(
            _getNotificationTypeIcon(notification.type),
            color: FlownetColors.pureWhite,
            size: 20,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight:
                notification.isRead ? FontWeight.normal : FontWeight.bold,
            color: FlownetColors.pureWhite,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.message,
              style: const TextStyle(
                color: FlownetColors.coolGray,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(notification.timestamp),
              style: const TextStyle(
                color: FlownetColors.coolGray,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: notification.isRead
            ? null
            : IconButton(
                icon: const Icon(Icons.mark_email_read,
                    color: FlownetColors.electricBlue),
                onPressed: () => _markAsRead(notification.id),
                tooltip: 'Mark as read',
              ),
        isThreeLine: true,
        onTap: () => _showNotificationDetail(notification),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final unreadCount = _notifications.where((n) => !n.isRead).length;
    final totalCount = _notifications.length;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          _buildSummaryCard(
            value: unreadCount,
            label: 'Unread',
            color: FlownetColors.electricBlue,
          ),
          const SizedBox(width: 16),
          _buildSummaryCard(
            value: totalCount,
            label: 'Total',
            color: FlownetColors.slate,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required int value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha((0.55 * 255).toInt()),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(
                color: FlownetColors.pureWhite,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: FlownetColors.pureWhite,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getNotificationTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.approval:
      case NotificationType.reportApproved:
        return Colors.green;
      case NotificationType.reportChangesRequested:
      case NotificationType.sprint:
        return Colors.orange;
      case NotificationType.system:
      case NotificationType.reportSubmission:
        return FlownetColors.electricBlue;
      case NotificationType.deliverable:
      case NotificationType.repository:
      case NotificationType.team:
      case NotificationType.file:
        return FlownetColors.charcoalBlack;
    }
  }

  IconData _getNotificationTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.approval:
      case NotificationType.reportApproved:
        return Icons.check_circle;
      case NotificationType.reportChangesRequested:
        return Icons.edit_note;
      case NotificationType.sprint:
        return Icons.directions_run;
      case NotificationType.system:
        return Icons.settings;
      case NotificationType.reportSubmission:
        return Icons.assignment_turned_in;
      case NotificationType.deliverable:
        return Icons.assignment;
      case NotificationType.repository:
        return Icons.code;
      case NotificationType.team:
        return Icons.people;
      case NotificationType.file:
        return Icons.insert_drive_file;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inDays < 1) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  Future<void> _markAsRead(String id) async {
// Optimistic update
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
      }
    });
    try {
      final token = _authService.accessToken;
      if (token != null) {
        _notificationService.setAuthToken(token);
      }
      await _notificationService.markAsRead(id);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      // Revert if needed, but for now we'll just reload on next visit
    }
  }

  Future<void> _markAllAsRead() async {
    // Optimistic update
    setState(() {
      _notifications =
          _notifications.map((n) => n.copyWith(isRead: true)).toList();
    });

    try {
      final token = _authService.accessToken;
      if (token != null) {
        _notificationService.setAuthToken(token);
      }
      final success = await _notificationService.markAllAsRead();

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All notifications marked as read'),
              backgroundColor: FlownetColors.electricBlue,
            ),
          );
        } else {
          // If failed, reload to show correct state
          _loadNotifications();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update notifications'),
              backgroundColor: FlownetColors.crimsonRed,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error marking all as read: $e');
      if (mounted) {
        _loadNotifications();
      }
    }
  }

  Future<void> _showNotificationDetail(NotificationItem notification) async {
    final wasRead = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            NotificationDetailScreen(notification: notification),
      ),
    );

    // If the notification was marked as read in the detail screen (returns true),
    // update the local state to reflect that.
    if (wasRead == true && !notification.isRead) {
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = _notifications[index].copyWith(isRead: true);
        }
      });
    }
  }
}
