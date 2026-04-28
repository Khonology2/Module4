// ignore_for_file: avoid_print

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/client_approval_request.dart';
import '../providers/client_approval_provider.dart';
import '../providers/notification_provider.dart';
import '../models/notification_item.dart';

/// Service for automatically sending reminders for pending client approvals
class ReminderService {
  final Ref ref;
  Timer? _reminderTimer;

  ReminderService(this.ref);

  /// Start the automatic reminder service
  void start() {
    // Check every 30 minutes for pending approvals that need reminders
    _reminderTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      _checkAndSendReminders();
    });

    // Also run an immediate check on startup
    _checkAndSendReminders();
  }

  /// Stop the reminder service
  void stop() {
    _reminderTimer?.cancel();
    _reminderTimer = null;
  }

  /// Check for pending approvals and send reminders if needed
  Future<void> _checkAndSendReminders() async {
    try {
      final approvalNotifier = ref.read(clientApprovalProvider.notifier);
      final notificationNotifier = ref.read(notificationProvider.notifier);

      // Get all pending approvals that need reminders
      final approvalsNeedingReminders = approvalNotifier.getApprovalsNeedingReminder();

      for (final approval in approvalsNeedingReminders) {
        await _sendReminderForApproval(approval, approvalNotifier, notificationNotifier);
      }
    } catch (e) {
      print('Error in reminder service: $e');
    }
  }

  /// Send a reminder for a specific approval
  Future<void> _sendReminderForApproval(
    ClientApprovalRequest approval,
    ClientApprovalNotifier approvalProvider,
    NotificationNotifier notificationProvider,
  ) async {
    try {
      // Send the reminder through the approval provider
      await approvalProvider.sendReminder(approval.id);

      // Create a notification for the delivery manager
      final notification = NotificationItem(
        id: 'reminder_${approval.id}_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Reminder Sent to Client',
        description: 'Sent reminder to ${approval.clientName} for deliverable: ${approval.deliverableTitle}',
        date: DateTime.now(),
        isRead: false,
        type: NotificationType.approval,
        message: 'Sent reminder to ${approval.clientName} for deliverable: ${approval.deliverableTitle}',
        timestamp: DateTime.now(),
        action: NotificationAction.approvalReminder,
        relatedId: approval.id,
      );

      notificationProvider.addNotification(notification);

      print('Reminder sent for approval: ${approval.id}');
    } catch (e) {
      print('Failed to send reminder for approval ${approval.id}: $e');

      // Create error notification
      final errorNotification = NotificationItem(
        id: 'reminder_error_${approval.id}_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Reminder Failed',
        description: 'Failed to send reminder to ${approval.clientName} for ${approval.deliverableTitle}',
        date: DateTime.now(),
        isRead: false,
        type: NotificationType.system,
        message: 'Failed to send reminder to ${approval.clientName} for ${approval.deliverableTitle}',
        timestamp: DateTime.now(),
        action: NotificationAction.systemError,
        relatedId: approval.id,
      );

      notificationProvider.addNotification(errorNotification);
    }
  }

  /// Dispose the service
  void dispose() {
    stop();
  }
}

/// Provider for the reminder service
final reminderServiceProvider = Provider<ReminderService>((ref) {
  final service = ReminderService(ref);
  service.start();
  return service;
});