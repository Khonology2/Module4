import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/flownet_theme.dart';
import '../services/auth_service.dart';
import '../providers/service_providers.dart';
import '../utils/app_icons.dart';
import 'background_image.dart';
import 'sidebar_version_display.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final String iconName;
  final String route;
  final String? requiredPermission;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.iconName,
    required this.route,
    this.requiredPermission,
  });
}

class SidebarScaffold extends StatefulWidget {
  final Widget child;

  const SidebarScaffold({super.key, required this.child});

  @override
  State<SidebarScaffold> createState() => _SidebarScaffoldState();
}

class _SidebarScaffoldState extends State<SidebarScaffold> {
  static const double _sidebarWidth = 240;

  List<_NavItem> get _navItems {
    final authService = AuthService();
    final userRole = authService.currentUser?.role.toString().toLowerCase() ?? '';

    final isAdminLike = userRole.contains('admin') || userRole.contains('system');
    if (isAdminLike) {
      // Match the new system admin sidebar layout and ordering.
      return const [
        _NavItem(
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
          iconName: 'dashboard',
          route: '/dashboard',
        ),
        _NavItem(
          label: 'Projects',
          icon: Icons.folder_outlined,
          iconName: 'projects',
          route: '/projects',
        ),
        _NavItem(
          label: 'Sprints',
          icon: Icons.timer_outlined,
          iconName: 'sprints',
          route: '/sprint-console',
        ),
        _NavItem(
          label: 'Deliverables',
          icon: Icons.assignment_outlined,
          iconName: 'deliverables',
          route: '/deliverables-overview',
        ),
        _NavItem(
          label: 'Timeline',
          icon: Icons.calendar_today_outlined,
          iconName: 'timeline',
          route: '/timeline',
        ),
        _NavItem(
          label: 'Approval Requests',
          icon: Icons.assignment_outlined,
          iconName: 'approval_requests',
          route: '/approval-requests',
        ),
        _NavItem(
          label: 'Repository',
          icon: Icons.folder_outlined,
          iconName: 'repository',
          route: '/repository',
        ),
        _NavItem(
          label: 'Reports',
          icon: Icons.assessment_outlined,
          iconName: 'reports',
          route: '/report-repository',
        ),
        _NavItem(
          label: 'User Management',
          icon: Icons.admin_panel_settings_outlined,
          iconName: 'role_management',
          route: '/role-management',
        ),
      ];
    }

    // Role-based navigation items
    final List<_NavItem> allItems = [
      const _NavItem(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        iconName: 'dashboard',
        route: '/dashboard',
        requiredPermission: null,
      ),
      const _NavItem(
        label: 'Projects',
        icon: Icons.folder_outlined,
        iconName: 'projects',
        route: '/projects',
        requiredPermission: null,
      ),
      const _NavItem(
        label: 'Sprints',
        icon: Icons.timer_outlined,
        iconName: 'sprints',
        route: '/sprint-console',
        requiredPermission: 'view_sprints',
      ),
      const _NavItem(
        label: 'Deliverables',
        icon: Icons.assignment_outlined,
        iconName: 'deliverables',
        route: '/deliverables-overview',
        requiredPermission: null,
      ),
      const _NavItem(
        label: 'Timeline',
        icon: Icons.calendar_today_outlined,
        iconName: 'timeline',
        route: '/timeline',
        requiredPermission: null,
      ),
    ];

    // Role-specific items
    final List<_NavItem> roleSpecificItems = [];

    if (userRole.contains('delivery') || userRole.contains('project')) {
      // Delivery/Project managers get project-related access
      roleSpecificItems.addAll([
        const _NavItem(
          label: 'Approval Requests',
          icon: Icons.assignment_outlined,
          iconName: 'approval_requests',
          route: '/approval-requests',
          requiredPermission: 'view_approvals',
        ),
        const _NavItem(
          label: 'Repository',
          icon: Icons.folder_outlined,
          iconName: 'repository',
          route: '/repository',
          requiredPermission: 'view_all_deliverables',
        ),
        const _NavItem(
          label: 'Reports',
          icon: Icons.assessment_outlined,
          iconName: 'reports',
          route: '/report-repository',
          requiredPermission: 'view_all_deliverables',
        ),
      ]);
    } else if (userRole.contains('client')) {
      // Client reviewers get focused access
      roleSpecificItems.addAll([
        const _NavItem(
          label: 'Approval Requests',
          icon: Icons.assignment_outlined,
          iconName: 'approval_requests',
          route: '/approval-requests',
          requiredPermission: 'view_approvals',
        ),
        const _NavItem(
          label: 'Repository',
          icon: Icons.folder_outlined,
          iconName: 'repository',
          route: '/repository',
          requiredPermission: 'view_all_deliverables',
        ),
        const _NavItem(
          label: 'Reports',
          icon: Icons.assessment_outlined,
          iconName: 'reports',
          route: '/report-repository',
          requiredPermission: 'view_all_deliverables',
        ),
      ]);
    }

    // Combine core items with role-specific items
    final combinedItems = [...allItems, ...roleSpecificItems];

    // Filter items based on user permissions
    return combinedItems.where((item) {
      // Special flag: hide from sidebar even if user has permission
      if (item.requiredPermission == 'HIDE_FROM_SIDEBAR') return false;
      
      // Client users should not see Projects and Deliverables
      if (userRole.contains('client') && 
          (item.label == 'Projects' || item.label == 'Deliverables')) {
        return false;
      }
      
      if (item.requiredPermission == null) return true;
      return authService.hasPermission(item.requiredPermission!);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final sidebarColor =
        isDarkMode ? FlownetColors.surface : FlownetColors.pureWhite;
    final sidebarTextColor = isDarkMode ? Colors.white : Colors.black;

    String routeLocation = '/';
    try {
      final router = GoRouter.maybeOf(context);
      final uri = router?.routeInformationProvider.value.uri;
      if (uri != null) {
        routeLocation = uri.path;
      } else {
        routeLocation = ModalRoute.of(context)?.settings.name ?? '/';
      }
    } catch (_) {
      routeLocation = ModalRoute.of(context)?.settings.name ?? '/';
    }
    final isDesktop = MediaQuery.of(context).size.width > 768;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: BackgroundImage(
          child: Row(
            children: [
              _buildDesktopSidebar(routeLocation),
              Expanded(
                child: Container(
                  color: Colors.transparent,
                  child: Stack(
                    children: [
                      Positioned.fill(child: widget.child),
                      const Positioned(
                        left: 14,
                        bottom: 8,
                        child: SidebarVersionDisplay(isSidebarCollapsed: false),
                      ),
                      if (routeLocation != '/dashboard')
                        Positioned(
                          right: 20,
                          bottom: 96,
                          child: _buildThemeToggleButton(isDarkMode),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Mobile layout with drawer
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: BackgroundImage(
          child: widget.child,
        ),
        floatingActionButton:
            routeLocation == '/dashboard' ? null : _buildThemeToggleButton(isDarkMode),
        drawer: Drawer(
          backgroundColor: sidebarColor,
          child: Column(
            children: [
              // Drawer header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: FlownetColors.coolGray,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/flownet_logo.png',
                      height: 32,
                      width: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Flow-Space',
                        style: TextStyle(
                          color: sidebarTextColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: sidebarTextColor),
                    ),
                  ],
                ),
              ),
              // Navigation items
              Expanded(
                child: _buildNavigationItems(isMobile: true),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildNavigationItems({required bool isMobile}) {
    final routeLocation = GoRouterState.of(context).uri.path;

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _navItems.length,
      itemBuilder: (context, index) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final sidebarTextColor = isDarkMode ? Colors.white : Colors.black;
        final sidebarSubtleText = isDarkMode ? FlownetColors.textSecondary : Colors.black87;
        final item = _navItems[index];
        final active = routeLocation.startsWith(item.route);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: AppIcons.getIconWidget(
              item.iconName,
              fallbackIcon: item.icon,
              isActive: active,
              size: 20,
              color: active ? sidebarTextColor : sidebarSubtleText,
            ),
            title: Text(
              item.label,
              style: TextStyle(
                color: active ? sidebarTextColor : sidebarSubtleText,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            onTap: () {
              if (!routeLocation.startsWith(item.route)) {
                context.go(item.route);
                Navigator.pop(context); // Close drawer on mobile
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildDesktopSidebar(String routeLocation) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color sidebarBackground =
        isDarkMode ? const Color(0xFF0C0C0C) : const Color(0xFFE8E8E8);
    final Color sidebarBorder =
        isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFD2D2D2);
    final Color sidebarText =
        isDarkMode ? Colors.white : const Color(0xFF141414);
    final Color subtitleText = isDarkMode
        ? Colors.white.withAlpha((0.82 * 255).round())
        : const Color(0xFF3F3F3F);

    return Container(
      width: _sidebarWidth,
      decoration: BoxDecoration(
        color: sidebarBackground,
        border: Border(
          right: BorderSide(color: sidebarBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: sidebarBorder, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'K H O N O L O G Y',
                  style: TextStyle(
                    color: Color(0xFFE02020),
                    fontSize: 13,
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome to\nDeliverable & Sprint Sign-Off Hub',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: subtitleText,
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final active = routeLocation.startsWith(item.route);
                return _buildDesktopNavItem(item, active, routeLocation);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Divider(color: sidebarBorder, height: 1),
          ),
          _buildDesktopFooterItem(
            label: 'Account Profile',
            iconName: 'account',
            fallbackIcon: Icons.person_outline,
            route: '/profile',
            currentRoute: routeLocation,
            textColor: sidebarText,
          ),
          _buildDesktopFooterItem(
            label: 'Logout',
            iconName: 'logout',
            fallbackIcon: Icons.logout,
            onTap: () => _handleLogout(context),
            currentRoute: routeLocation,
            textColor: sidebarText,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDesktopNavItem(
    _NavItem item,
    bool active,
    String routeLocation,
  ) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color navText = isDarkMode ? Colors.white : const Color(0xFF141414);
    return Container(
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFD70E0E) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: GestureDetector(
        onTap: () {
          if (!routeLocation.startsWith(item.route)) {
            context.go(item.route);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFFE9E9E9),
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: AppIcons.getIconWidget(
                  item.iconName,
                  fallbackIcon: item.icon,
                  isActive: false,
                  size: 16,
                  visualScale: 2.2,
                  fit: BoxFit.cover,
                  color: const Color(0xFF121212),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: active ? Colors.white : navText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopFooterItem({
    required String label,
    required String iconName,
    required IconData fallbackIcon,
    required String currentRoute,
    required Color textColor,
    String? route,
    VoidCallback? onTap,
  }) {
    final bool active = route != null && currentRoute.startsWith(route);
    return Container(
      height: 36,
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFD70E0E) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: GestureDetector(
        onTap: () {
          if (onTap != null) {
            onTap();
            return;
          }
          if (route != null && !currentRoute.startsWith(route)) {
            context.go(route);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFFE9E9E9),
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: AppIcons.getIconWidget(
                  iconName,
                  fallbackIcon: fallbackIcon,
                  isActive: false,
                  size: 16,
                  visualScale: 2.2,
                  fit: BoxFit.cover,
                  color: const Color(0xFF121212),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : textColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggleButton(bool isDarkMode) {
    return FloatingActionButton.small(
      heroTag: null,
      onPressed: () {
        ProviderScope.containerOf(context, listen: false)
            .read(themeProvider.notifier)
            .toggleTheme();
      },
      backgroundColor: isDarkMode ? FlownetColors.surface : FlownetColors.pureWhite,
      foregroundColor: isDarkMode ? Colors.white : Colors.black,
      child: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
    );
  }

  Future<void> _handleLogout(BuildContext ctx) async {
    final router = GoRouter.of(ctx);
    await AuthService().signOut();
    if (!mounted) return;
    router.go('/');
  }

}
