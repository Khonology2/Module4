import 'package:flutter/material.dart';

/// Utility class for managing app icons.
/// Provides a centralized way to get icons by name with fallback support.
class AppIcons {
  static String _getIconPath(String iconName, bool isActive) {
    // Map app iconName keys to the exact icon filenames.
    // NOTE: icon files use a double extension: *.png.png
    final iconPaths = <String, Map<String, String>>{
      'dashboard': {
        'active': 'assets/Dashboard2.png',
        'inactive': 'assets/Dashboard2.png',
      },
      'projects': {
        'active': 'assets/Projects.png',
        'inactive': 'assets/Projects.png',
      },
      'deliverables': {
        'active': 'assets/Deliverables.png',
        'inactive': 'assets/Deliverables.png',
      },
      'sprints': {
        'active': 'assets/Sprints.png',
        'inactive': 'assets/Sprints.png',
      },
      'notifications': {
        'active': 'assets/Icons/Notifications active.png.png',
        'inactive': 'assets/Icons/Notifications inactive.png.png',
      },
      'repository': {
        'active': 'assets/Repository.png',
        'inactive': 'assets/Repository.png',
      },
      'approval_requests': {
        'active': 'assets/Approval_Requests.png',
        'inactive': 'assets/Approval_Requests.png',
      },
      'approvals': {
        'active': 'assets/Icons/Data_Approvals active.png.png',
        'inactive': 'assets/Icons/Data_Approvals inactive.png.png',
      },
      'reports': {
        'active': 'assets/reports.png',
        'inactive': 'assets/reports.png',
      },
      'role_management': {
        'active': 'assets/User_management_blue.png',
        'inactive': 'assets/User_management_blue.png',
      },
      'settings': {
        'active': 'assets/Icons/Settings active.png.png',
        'inactive': 'assets/Icons/Settings inactive.png.png',
      },
      'account': {
        'active': 'assets/Profile2.png',
        'inactive': 'assets/Profile2.png',
      },
      'logout': {
        'active': 'assets/Logout.png',
        'inactive': 'assets/Logout.png',
      },
      'timeline': {
        'active': 'assets/Timeline.png',
        'inactive': 'assets/Timeline.png',
      },
      'ai_assistant': {
        'active': 'assets/Icons/AI_Red.png',
        'inactive': 'assets/Icons/AI_Red.png',
      },
      'teams': {
        'active': 'assets/Icons/Home_Dashboard active.png.png',
        'inactive': 'assets/Icons/Home_Dashboard inactive.png.png',
      },
      'urgent_notifications': {
        'active': 'assets/Icons/Urgent Notifications active.png.png',
        'inactive': 'assets/Icons/Urgent Notifications inactive.png.png',
      },
      'chatbot': {
        'active': 'assets/Icons/AI_Red.png',
        'inactive': 'assets/Icons/AI_Red.png',
      },
    };

    final paths = iconPaths[iconName];
    if (paths == null) return '';
    return isActive ? paths['active']! : paths['inactive']!;
  }

  /// Get icon by name, with fallback to provided icon.
  static IconData getIcon(
    String iconName, {
    required IconData fallbackIcon,
  }) {
    final iconMap = <String, IconData>{
      'dashboard': Icons.dashboard_outlined,
      'projects': Icons.folder_outlined,
      'deliverables': Icons.rocket_launch_outlined,
      'sprints': Icons.timer_outlined,
      'notifications': Icons.notifications_outlined,
      'approvals': Icons.check_box_outlined,
      'approval_requests': Icons.assignment_outlined,
      'repository': Icons.folder_outlined,
      'reports': Icons.assessment_outlined,
      'role_management': Icons.admin_panel_settings_outlined,
      'settings': Icons.settings_outlined,
      'account': Icons.person_outline,
      'timeline': Icons.calendar_today_outlined,
      'ai_assistant': Icons.smart_toy_outlined,
    };

    return iconMap[iconName] ?? fallbackIcon;
  }

  /// Get icon widget by name.
  static Widget getIconWidget(
    String iconName, {
    required IconData fallbackIcon,
    bool isActive = false,
    double size = 24.0,
    Color? color,
    double visualScale = 1.0,
    BoxFit fit = BoxFit.contain,
  }) {
    final assetPath = _getIconPath(iconName, isActive);
    if (assetPath.isNotEmpty) {
      return Transform.scale(
        scale: visualScale,
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: fit,
          filterQuality: FilterQuality.none,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Failed to load icon asset: $assetPath -> $error');
            return Icon(
              getIcon(iconName, fallbackIcon: fallbackIcon),
              size: size,
              color: color,
            );
          },
        ),
      );
    }

    return Icon(
      getIcon(iconName, fallbackIcon: fallbackIcon),
      size: size,
      color: color,
    );
  }
}
