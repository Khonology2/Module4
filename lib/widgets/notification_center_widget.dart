import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import '../services/notification_service.dart';
import '../services/realtime_service.dart';
import '../services/auth_service.dart';
import '../theme/flownet_theme.dart';
import 'interactive_header_icon.dart';

class NotificationCenterWidget extends StatefulWidget {
  final bool showLabel;
  final bool showBackground;
  /// Red circular button (e.g. dashboard header); keeps unread badge.
  final bool circularRedButton;

  /// Light circular button with red bell (Client Dashboard header mock).
  final bool circularLightButton;

  const NotificationCenterWidget({
    super.key,
    this.showLabel = true,
    this.showBackground = true,
    this.circularRedButton = false,
    this.circularLightButton = false,
  });

  @override
  State<NotificationCenterWidget> createState() =>
      _NotificationCenterWidgetState();
}

class _NotificationCenterWidgetState extends State<NotificationCenterWidget> {
  final NotificationService _notificationService = NotificationService();
  final AuthService _authService = AuthService();
  late RealtimeService _realtime;
  late Function(dynamic) _notificationListener;
  StreamSubscription<bool>? _connectionSubscription;

  int _unreadCount = 0;
  bool _isLoading = true;
  final bool _disposed = false;
  final Set<String> _processedNotificationIds = {}; // Prevent duplicates

  @override
  void initState() {
    super.initState();
    _realtime = RealtimeService();

    // Ensure we have a token before initializing realtime
    final token = _authService.accessToken;
    if (token != null) {
      _realtime.initialize(authToken: token);
    }

    // Listen to connection status to reload count when reconnected
    _connectionSubscription = _realtime.connectionStream.listen((connected) {
      if (connected) {
        _loadUnreadCount();
      }
    });

    // Store listener reference to remove it properly later
    _notificationListener = (data) {
      if (_disposed) return;

      debugPrint('🔔 Notification received in widget: $data');

      // Prevent duplicate notifications
      String? notificationId;
      if (data is Map && data['id'] != null) {
        notificationId = data['id'].toString();
      } else if (data is Map &&
          data['notification'] != null &&
          data['notification']['id'] != null) {
        notificationId = data['notification']['id'].toString();
      }

      if (notificationId != null) {
        if (_processedNotificationIds.contains(notificationId)) {
          debugPrint('🔔 Duplicate notification ignored: $notificationId');
          return;
        }
        _processedNotificationIds.add(notificationId);

        // Clean up old IDs to prevent memory leaks
        if (_processedNotificationIds.length > 100) {
          _processedNotificationIds.remove(_processedNotificationIds.first);
        }
      }

      // Handle role broadcasts for cross-portal synchronization
      if (data is Map && data['sync_type'] == 'role_broadcast') {
        debugPrint('🔔 Role broadcast received: ${data['target_role']}');
        // Only refresh if this is relevant to the current user
        _loadUnreadCount();
        return;
      }

      // Handle notification count updates
      if (data is Map && data['unreadCount'] != null) {
        if (mounted && !_disposed) {
          setState(() {
            _unreadCount = data['unreadCount'] as int;
          });
        }
        return;
      }

      // Standard notification received
      _loadUnreadCount();
    };

    _realtime.on('notification_received', _notificationListener);
    _realtime.on('notifications_updated', _notificationListener);

    // Initial load
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    if (_disposed) return;

    try {
      String? token = _authService.accessToken;
      if (token == null) {
        await _authService.initialize();
        token = _authService.accessToken;
      }

      if (token != null) {
        _notificationService.setAuthToken(token);
        final notifications = await _notificationService.getNotifications();
        final int count = notifications.where((n) => !n.isRead).length;
        debugPrint('🔔 Loaded unread count from notifications: $count');
        if (mounted) {
          setState(() {
            _unreadCount = count;
            _isLoading = false;
          });
        }
      } else {
        debugPrint('⚠️ No auth token available for loading unread count');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading notification count: $e');
      if (mounted && !_disposed) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    // Only remove our specific listeners, not all listeners
    _realtime.off('notification_received', _notificationListener);
    _realtime.off('notifications_updated', _notificationListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            Icon(
              Icons.notifications_outlined,
              color: widget.showBackground
                  ? FlownetColors.pureWhite
                  : Colors.white,
              size: 24, // Standard icon size
            ),
            if (_unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: FlownetColors.crimsonRed,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Center(
                    child: Text(
                      _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                      style: const TextStyle(
                        color: FlownetColors.pureWhite,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (widget.showLabel) ...[
          const SizedBox(width: 8),
          if (_isLoading)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(FlownetColors.pureWhite),
              ),
            )
          else
            const Text(
              'Notifications',
              style: TextStyle(
                color: FlownetColors.pureWhite,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ],
    );

    if (widget.circularLightButton) {
      final path = GoRouterState.of(context).uri.path;
      final onNotifications = path == '/notifications' ||
          path.startsWith('/notifications/');
      return Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            context.go('/notifications');
            _loadUnreadCount();
          },
          child: Tooltip(
            message: 'Notifications',
            child: InteractiveHeaderIcon(
              inactiveAsset: 'assets/Icons/header_notifications_inactive.png',
              activeAsset: 'assets/Icons/header_notifications_active.png',
              routeActive: onNotifications,
              size: 44,
              overlay: _unreadCount > 0
                  ? Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: FlownetColors.crimsonRed,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 14,
                        ),
                        child: Center(
                          child: Text(
                            _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                            style: const TextStyle(
                              color: FlownetColors.pureWhite,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      );
    }

    if (widget.circularRedButton) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            context.go('/notifications');
            _loadUnreadCount();
          },
          child: Tooltip(
            message: 'Notifications',
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: FlownetColors.crimsonRed,
                shape: BoxShape.circle,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_outlined,
                    color: FlownetColors.pureWhite,
                    size: 22,
                  ),
                  if (_unreadCount > 0)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: FlownetColors.pureWhite,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: FlownetColors.crimsonRed,
                            width: 1,
                          ),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Center(
                          child: Text(
                            _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                            style: const TextStyle(
                              color: FlownetColors.crimsonRed,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (widget.showBackground) {
      return GestureDetector(
        onTap: () {
          context.go('/notifications');
          _loadUnreadCount();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: FlownetColors.graphiteGray,
            borderRadius: BorderRadius.circular(8),
          ),
          child: content,
        ),
      );
    } else {
      return IconButton(
        icon: content,
        onPressed: () {
          context.go('/notifications');
          _loadUnreadCount();
        },
        tooltip: 'Notifications',
      );
    }
  }
}
