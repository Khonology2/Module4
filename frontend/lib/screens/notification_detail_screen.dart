import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_item.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme/flownet_theme.dart';
import '../widgets/app_scaffold.dart';
import 'client_review_workflow_screen.dart';
import 'report_editor_screen.dart';

class NotificationDetailScreen extends ConsumerStatefulWidget {
  final NotificationItem notification;

  const NotificationDetailScreen({
    super.key,
    required this.notification,
  });

  @override
  ConsumerState<NotificationDetailScreen> createState() => _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends ConsumerState<NotificationDetailScreen> {
  final NotificationService _notificationService = NotificationService();
  final AuthService _authService = AuthService();
  late NotificationItem _notification;

  @override
  void initState() {
    super.initState();
    _notification = widget.notification;
    _initializeAndMarkRead();
  }

  Future<void> _initializeAndMarkRead() async {
    final token = _authService.accessToken;
    if (token != null) {
      _notificationService.setAuthToken(token);
    }

    if (!_notification.isRead) {
      final success = await _notificationService.markAsRead(_notification.id);
      if (success && mounted) {
        setState(() {
          _notification = _notification.copyWith(isRead: true);
        });
      }
    }
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

  void _handleAction() {
    final relatedId = _notification.relatedId;
    if (relatedId == null) return;

    switch (_notification.type) {
      case NotificationType.reportChangesRequested:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReportEditorScreen(reportId: relatedId),
          ),
        );
        break;
      case NotificationType.reportSubmission:
      case NotificationType.reportApproved:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClientReviewWorkflowScreen(reportId: relatedId),
          ),
        );
        break;
      // Add more cases as needed
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No action available for this notification')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      useBackgroundImage: true,
      centered: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Notification Details',
          style: TextStyle(color: FlownetColors.pureWhite),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: FlownetColors.pureWhite),
          onPressed: () => Navigator.pop(context, _notification.isRead), // Return read status
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _getNotificationTypeColor(_notification.type),
                  child: Icon(
                    _getNotificationTypeIcon(_notification.type),
                    color: FlownetColors.pureWhite,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _notification.title,
                        style: const TextStyle(
                          color: FlownetColors.pureWhite,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestamp(_notification.timestamp),
                        style: const TextStyle(
                          color: FlownetColors.coolGray,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: FlownetColors.slate.withAlpha(100),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: FlownetColors.slate.withAlpha(200),
                ),
              ),
              child: Text(
                _notification.message,
                style: const TextStyle(
                  color: FlownetColors.pureWhite,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: FlownetColors.charcoalBlack.withAlpha(150),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'METADATA',
                    style: TextStyle(
                      color: FlownetColors.electricBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMetaRow('Type', _notification.type.name.toUpperCase()),
                  _buildMetaRow('Status', _notification.isRead ? 'Read' : 'Unread'),
                  if (_notification.relatedId != null)
                    _buildMetaRow('Related ID', _notification.relatedId!),
                ],
              ),
            ),
            const SizedBox(height: 48),
            if (_notification.relatedId != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _handleAction,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('View Related Item'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlownetColors.electricBlue,
                    foregroundColor: FlownetColors.pureWhite,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: FlownetColors.coolGray,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: FlownetColors.pureWhite,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
