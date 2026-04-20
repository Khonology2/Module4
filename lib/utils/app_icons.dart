import 'package:flutter/material.dart';

/// Utility class for managing app icons.
/// Provides a centralized way to get icons by name with fallback support.
class AppIcons {
  /// Sidebar “Account Profile” + header profile control (single badge art).
  /// Space-free path so assets load reliably on web and all platforms.
  static const String accountProfileBadgeAsset =
      'assets/Icons/account_profile_white_badge_blue.png';

  /// Sidebar Dashboard nav (active + inactive — same art per design).
  static const String dashboardSidebarAsset =
      'assets/Icons/dashboard_white_badge_blue.png';

  /// Dashboard row icon — direct [Image.asset] (same pattern as [accountProfileBadge]).
  static Widget dashboardSidebarBadge({double size = 24.0}) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        dashboardSidebarAsset,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          debugPrint(
            'AppIcons.dashboardSidebarBadge failed path=$dashboardSidebarAsset error=$error',
          );
          return Icon(Icons.dashboard_outlined, size: size);
        },
      ),
    );
  }

  /// Sidebar Projects nav (Project Management white badge; active + inactive).
  static const String projectsSidebarAsset =
      'assets/Icons/projects_white_badge_blue.png';

  static Widget projectsSidebarBadge({double size = 24.0}) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        projectsSidebarAsset,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          debugPrint(
            'AppIcons.projectsSidebarBadge failed path=$projectsSidebarAsset error=$error',
          );
          return Icon(Icons.folder_outlined, size: size);
        },
      ),
    );
  }

  /// Sidebar Deliverables nav (Send Paper Plane white badge; active + inactive).
  static const String deliverablesSidebarAsset =
      'assets/Icons/deliverables_white_badge_blue.png';

  static Widget deliverablesSidebarBadge({double size = 24.0}) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        deliverablesSidebarAsset,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          debugPrint(
            'AppIcons.deliverablesSidebarBadge failed path=$deliverablesSidebarAsset error=$error',
          );
          return Icon(Icons.rocket_launch_outlined, size: size);
        },
      ),
    );
  }

  /// Sidebar Timeline nav (Time Allocation / clock-check white badge; active + inactive).
  static const String timelineSidebarAsset =
      'assets/Icons/timeline_white_badge_blue.png';

  static Widget timelineSidebarBadge({double size = 24.0}) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        timelineSidebarAsset,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          debugPrint(
            'AppIcons.timelineSidebarBadge failed path=$timelineSidebarAsset error=$error',
          );
          return Icon(Icons.calendar_today_outlined, size: size);
        },
      ),
    );
  }

  /// Sidebar Approval Requests nav (Search/Seek white badge; active + inactive).
  static const String approvalRequestsSidebarAsset =
      'assets/Icons/approval_requests_white_badge_blue.png';

  static Widget approvalRequestsSidebarBadge({double size = 24.0}) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        approvalRequestsSidebarAsset,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          debugPrint(
            'AppIcons.approvalRequestsSidebarBadge failed path=$approvalRequestsSidebarAsset error=$error',
          );
          return Icon(Icons.assignment_outlined, size: size);
        },
      ),
    );
  }

  /// Sidebar Repository nav (Task Management white badge; active + inactive).
  static const String repositorySidebarAsset =
      'assets/Icons/repository_white_badge_blue.png';

  static Widget repositorySidebarBadge({double size = 24.0}) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        repositorySidebarAsset,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          debugPrint(
            'AppIcons.repositorySidebarBadge failed path=$repositorySidebarAsset error=$error',
          );
          return Icon(Icons.folder_outlined, size: size);
        },
      ),
    );
  }

  /// Sidebar Reports nav (document + charts white badge; active + inactive).
  static const String reportsSidebarAsset =
      'assets/Icons/reports_white_badge_blue.png';

  static Widget reportsSidebarBadge({double size = 24.0}) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        reportsSidebarAsset,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          debugPrint(
            'AppIcons.reportsSidebarBadge failed path=$reportsSidebarAsset error=$error',
          );
          return Icon(Icons.assessment_outlined, size: size);
        },
      ),
    );
  }

  /// Header notifications bell (white badge; active/hover use same art as [InteractiveHeaderIcon]).
  static const String notificationsHeaderAsset =
      'assets/Icons/notifications_white_badge_blue.png';

  /// Profile / “Account Profile” control (sidebar, menus). Uses [Image.asset]
  /// directly so it does not depend on the icon map lookup.
  ///
  /// **Note:** After adding or changing this asset, do a **full restart**
  /// (not hot reload) so Flutter picks up the updated asset manifest.
  static Widget accountProfileBadge({double size = 24.0}) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        accountProfileBadgeAsset,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          debugPrint(
            'AppIcons.accountProfileBadge failed path=$accountProfileBadgeAsset error=$error',
          );
          return Icon(
            Icons.person_outline,
            size: size,
          );
        },
      ),
    );
  }

  static String _getIconPath(String iconName, bool isActive) {
    // Map app iconName keys to the exact icon filenames.
    // NOTE: icon files use a double extension: *.png.png
    final iconPaths = <String, Map<String, String>>{
      'dashboard': {
        'active': dashboardSidebarAsset,
        'inactive': dashboardSidebarAsset,
      },
      'projects': {
        'active': projectsSidebarAsset,
        'inactive': projectsSidebarAsset,
      },
      'deliverables': {
        'active': deliverablesSidebarAsset,
        'inactive': deliverablesSidebarAsset,
      },
      'sprints': {
        'active': 'assets/Icons/Sprints console active.png.png',
        'inactive': 'assets/Icons/Sprints console inactive.png.png',
      },
      'notifications': {
        'active': 'assets/Icons/Notifications active.png.png',
        'inactive': 'assets/Icons/Notifications inactive.png.png',
      },
      'repository': {
        'active': 'assets/Icons/Group 308.png',
        'inactive': 'assets/Icons/Group 232.png',
      },
      'approval_requests': {
        'active': approvalRequestsSidebarAsset,
        'inactive': approvalRequestsSidebarAsset,
      },
      'approvals': {
        'active': 'assets/Icons/Data_Approvals active.png.png',
        'inactive': 'assets/Icons/Data_Approvals inactive.png.png',
      },
      'reports': {
        'active': reportsSidebarAsset,
        'inactive': reportsSidebarAsset,
      },
      'role_management': {
        'active': 'assets/Icons/Role Managemet active.png.png',
        'inactive': 'assets/Icons/Role Managemet inactive.png.png',
      },
      'settings': {
        'active': 'assets/Icons/Settings active.png.png',
        'inactive': 'assets/Icons/Settings inactive.png.png',
      },
      'account': {
        'active': accountProfileBadgeAsset,
        'inactive': accountProfileBadgeAsset,
      },
      'logout': {
        'active': 'assets/Icons/Logout_KhonoBuzz.png',
        'inactive': 'assets/Icons/Logout_KhonoBuzz.png',
      },
      'timeline': {
        'active': timelineSidebarAsset,
        'inactive': timelineSidebarAsset,
      },
      // AI Assistant: inactive = light/white treatment (unselected); active = red (selected route)
      'ai_assistant': {
        'active': 'assets/Icons/ai_assistant_active.png',
        'inactive': 'assets/Icons/ai_assistant_inactive.png',
      },
      'teams': {
        'active': dashboardSidebarAsset,
        'inactive': dashboardSidebarAsset,
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
  }) {
    if (iconName == 'dashboard') {
      return dashboardSidebarBadge(size: size);
    }
    if (iconName == 'projects') {
      return projectsSidebarBadge(size: size);
    }
    if (iconName == 'deliverables') {
      return deliverablesSidebarBadge(size: size);
    }
    if (iconName == 'timeline') {
      return timelineSidebarBadge(size: size);
    }
    if (iconName == 'approval_requests') {
      return approvalRequestsSidebarBadge(size: size);
    }
    if (iconName == 'repository') {
      return repositorySidebarBadge(size: size);
    }
    if (iconName == 'reports') {
      return reportsSidebarBadge(size: size);
    }
    final assetPath = _getIconPath(iconName, isActive);
    if (assetPath.isNotEmpty) {
      return Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Failed to load icon asset: $assetPath -> $error');
          return Icon(
            getIcon(iconName, fallbackIcon: fallbackIcon),
            size: size,
            color: color,
          );
        },
      );
    }

    return Icon(
      getIcon(iconName, fallbackIcon: fallbackIcon),
      size: size,
      color: color,
    );
  }
}
