import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/realtime_service.dart';
import '../providers/service_providers.dart';
import '../theme/flownet_theme.dart';
import '../widgets/flownet_logo.dart';
import '../widgets/app_modal.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends ConsumerState<NotificationCenterScreen> {
  List<NotificationItem> _notifications = [];
  String _selectedFilter = 'all';
  bool _showReadOnly = false;
  bool _isLoading = false;
  late RealtimeService _realtime;

  @override
  void initState() {
    super.initState();
    _realtime = RealtimeService();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final backendService = ref.read(backendApiServiceProvider);
      final response = await backendService.getNotifications();
      
      if (response.isSuccess && response.data != null) {
        final raw = response.data;
        final List<dynamic> notificationsData = raw is List
            ? raw
            : (raw is Map
                ? (raw['data'] ?? raw['notifications'] ?? raw['items'] ?? [])
                : []);
        
        final notifications = notificationsData
            .whereType<Map>()
            .map((notificationData) => NotificationItem.fromJson(Map<String, dynamic>.from(notificationData)))
            .toList();

        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      } else {
        // No notifications available
        setState(() {
          _notifications = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      setState(() {
        _notifications = [];
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _realtime.offAll('notification_received');
    _realtime.offAll('notifications_updated');
    super.dispose();
  }



  List<NotificationItem> get _filteredNotifications {
    var filtered = _notifications;

    // Apply type filter
    if (_selectedFilter != 'all') {
      final type = NotificationType.values.firstWhere(
        (e) => e.name == _selectedFilter,
        orElse: () => NotificationType.review,
      );
      filtered = filtered.where((notification) => notification.type == type).toList();
    }

    // Apply read filter
    if (_showReadOnly) {
      filtered = filtered.where((notification) => notification.isRead).toList();
    }

    // Sort by priority and date
    filtered.sort((a, b) {
      if (a.priority.index != b.priority.index) {
        return a.priority.index.compareTo(b.priority.index);
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    return filtered;
  }

  Future<void> _markAsRead(NotificationItem notification) async {
    try {
      final backendService = ref.read(backendApiServiceProvider);
      final resp = await backendService.markNotificationAsRead(notification.id);
      if (!resp.isSuccess) {
        // Silent fallback; keep local state consistent
      }
    } catch (_) {}
    setState(() {
      notification.isRead = true;
    });
  }

  Future<void> _markAllAsRead() async {
    try {
      final backendService = ref.read(backendApiServiceProvider);
      await backendService.markAllNotificationsAsRead();
    } catch (_) {}
    setState(() {
      for (var notification in _notifications) {
        notification.isRead = true;
      }
    });
  }

  void _handleNotificationTap(NotificationItem notification) {
    _markAsRead(notification);
    
    // Navigate based on notification type
    switch (notification.type) {
      case NotificationType.review:
        if (notification.reportId != null) {
          // Navigate to client review
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Navigating to review for ${notification.deliverableId}'),
              backgroundColor: Colors.blue,
            ),
          );
        }
        break;
      case NotificationType.changeRequest:
        if (notification.deliverableId != null) {
          // Navigate to change request details
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Navigating to change request for ${notification.deliverableId}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        break;
      case NotificationType.report:
        if (notification.reportId != null) {
          // Navigate to report
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Navigating to report ${notification.reportId}'),
              backgroundColor: Colors.green,
            ),
          );
        }
        break;
      case NotificationType.metrics:
        if (notification.sprintId != null) {
          // Navigate to sprint metrics
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Navigating to sprint metrics for ${notification.sprintId}'),
              backgroundColor: Colors.purple,
            ),
          );
        }
        break;
      case NotificationType.reminder:
        // Show reminder details
        _showReminderDialog(notification);
        break;
      case NotificationType.approval:
        // Show approval details
        _showApprovalDialog(notification);
        break;
    }
  }

  void _showReminderDialog(NotificationItem notification) {
    showAppDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FlownetColors.graphiteGray,
        title: const Row(
          children: [
            Icon(Icons.schedule, color: Colors.orange),
            SizedBox(width: 8),
            Text('Reminder'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.title),
            const SizedBox(height: 8),
            Text(notification.message),
            if (notification.dueDate != null) ...[
              const SizedBox(height: 8),
              Text(
                'Due: ${_formatDate(notification.dueDate!)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          if (notification.deliverableId != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _handleNotificationTap(notification);
              },
              child: const Text('Review Now'),
            ),
        ],
      ),
    );
  }

  void _showApprovalDialog(NotificationItem notification) {
    showAppDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FlownetColors.graphiteGray,
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Approval Confirmed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.title),
            const SizedBox(height: 8),
            Text(notification.message),
            const SizedBox(height: 8),
            Text(
              'Approved on: ${_formatDate(notification.createdAt)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Helper methods for parsing notification data from API
  

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: FlownetColors.charcoalBlack,
        appBar: AppBar(
          title: const FlownetLogo(),
          backgroundColor: FlownetColors.charcoalBlack,
          foregroundColor: FlownetColors.pureWhite,
          centerTitle: false,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: FlownetColors.electricBlue,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: FlownetColors.charcoalBlack,
      appBar: AppBar(
        title: const FlownetLogo(),
        backgroundColor: FlownetColors.charcoalBlack,
        foregroundColor: FlownetColors.pureWhite,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read),
            onPressed: _markAllAsRead,
            tooltip: 'Mark All as Read',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter and Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'All'),
                      const SizedBox(width: 8),
                      _buildFilterChip('review', 'Reviews'),
                      const SizedBox(width: 8),
                      _buildFilterChip('changeRequest', 'Change Requests'),
                      const SizedBox(width: 8),
                      _buildFilterChip('report', 'Reports'),
                      const SizedBox(width: 8),
                      _buildFilterChip('reminder', 'Reminders'),
                      const SizedBox(width: 8),
                      _buildFilterChip('approval', 'Approvals'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Read Filter
                Row(
                  children: [
                    Checkbox(
                      value: _showReadOnly,
                      onChanged: (value) {
                        setState(() {
                          _showReadOnly = value ?? false;
                        });
                      },
                      activeColor: FlownetColors.electricBlue,
                    ),
                    const Text('Show read notifications'),
                  ],
                ),
              ],
            ),
          ),

          // Notifications List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: FlownetColors.electricBlue,
                    ),
                  )
                : _filteredNotifications.isEmpty
                    ? const Center(
                        child: Text(
                          'No notifications found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredNotifications.length,
                        itemBuilder: (context, index) {
                          final notification = _filteredNotifications[index];
                          return _buildNotificationCard(notification);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      backgroundColor: FlownetColors.slate,
      selectedColor: FlownetColors.electricBlue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey,
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: notification.isRead ? FlownetColors.slate : FlownetColors.graphiteGray,
      child: InkWell(
        onTap: () => _handleNotificationTap(notification),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    _getNotificationIcon(notification.type),
                    color: _getNotificationColor(notification.type),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      notification.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (!notification.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: FlownetColors.electricBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Message
              Text(
                notification.message,
                style: TextStyle(
                  color: notification.isRead ? Colors.grey : Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),

              // Footer
              Row(
                children: [
                  _buildPriorityChip(notification.priority),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(notification.createdAt),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  if (notification.dueDate != null)
                    Text(
                      'Due: ${_formatDate(notification.dueDate!)}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityChip(NotificationPriority priority) {
    Color color;
    String label;
    
    switch (priority) {
      case NotificationPriority.low:
        color = Colors.grey;
        label = 'Low';
        break;
      case NotificationPriority.medium:
        color = Colors.blue;
        label = 'Medium';
        break;
      case NotificationPriority.high:
        color = Colors.orange;
        label = 'High';
        break;
      case NotificationPriority.urgent:
        color = Colors.red;
        label = 'Urgent';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.review:
        return Icons.rate_review;
      case NotificationType.changeRequest:
        return Icons.edit;
      case NotificationType.report:
        return Icons.assessment;
      case NotificationType.metrics:
        return Icons.analytics;
      case NotificationType.reminder:
        return Icons.schedule;
      case NotificationType.approval:
        return Icons.check_circle;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.review:
        return Colors.blue;
      case NotificationType.changeRequest:
        return Colors.orange;
      case NotificationType.report:
        return Colors.green;
      case NotificationType.metrics:
        return Colors.purple;
      case NotificationType.reminder:
        return Colors.red;
      case NotificationType.approval:
        return Colors.green;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

// Notification models
class NotificationItem {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final NotificationPriority priority;
  bool isRead;
  final DateTime createdAt;
  final String? deliverableId;
  final String? reportId;
  final String? sprintId;
  final DateTime? dueDate;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.isRead,
    required this.createdAt,
    this.deliverableId,
    this.reportId,
    this.sprintId,
    this.dueDate,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      type: NotificationItem._parseNotificationType(json['type']?.toString()),
      priority: NotificationItem._parseNotificationPriority(json['priority']?.toString()),
      isRead: json['is_read'] ?? json['isRead'] ?? false,
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt'] ?? DateTime.now().toIso8601String()),
      deliverableId: json['deliverable_id']?.toString(),
      reportId: json['report_id']?.toString(),
      sprintId: json['sprint_id']?.toString(),
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
    );
  }

  static NotificationType _parseNotificationType(String? type) {
    switch (type?.toLowerCase()) {
      case 'review':
        return NotificationType.review;
      case 'change_request':
      case 'changerequest':
        return NotificationType.changeRequest;
      case 'report':
        return NotificationType.report;
      case 'metrics':
        return NotificationType.metrics;
      case 'reminder':
        return NotificationType.reminder;
      case 'approval':
        return NotificationType.approval;
      default:
        return NotificationType.review;
    }
  }

  static NotificationPriority _parseNotificationPriority(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'urgent':
        return NotificationPriority.urgent;
      case 'high':
        return NotificationPriority.high;
      case 'medium':
        return NotificationPriority.medium;
      case 'low':
        return NotificationPriority.low;
      default:
        return NotificationPriority.medium;
    }
  }
}

enum NotificationType {
  review,
  changeRequest,
  report,
  metrics,
  reminder,
  approval,
}

enum NotificationPriority {
  low,
  medium,
  high,
  urgent,
}

