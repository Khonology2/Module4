// ignore_for_file: prefer_const_constructors, unused_import, unused_field

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../widgets/background_image.dart';
import '../utils/app_icons.dart';
import '../widgets/sidebar_version_display.dart';

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

    final userRole =
        authService.currentUser?.role.toString().toLowerCase() ?? '';

    final isAdminLike =
        userRole.contains('admin') || userRole.contains('system');

    final List<_NavItem> items;

    if (isAdminLike) {
      items = const [
        _NavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, iconName: 'dashboard', route: '/dashboard'),
        _NavItem(label: 'Projects', icon: Icons.folder_outlined, iconName: 'projects', route: '/projects'),
        _NavItem(label: 'Sprints', icon: Icons.timer_outlined, iconName: 'sprints', route: '/sprints'),
        _NavItem(label: 'Users', icon: Icons.people_outline, iconName: 'users', route: '/users'),
        _NavItem(label: 'Roles', icon: Icons.admin_panel_settings_outlined, iconName: 'roles', route: '/roles'),
        _NavItem(label: 'Repository', icon: Icons.folder_outlined, iconName: 'repository', route: '/repository'),
        _NavItem(label: 'Reports', icon: Icons.assessment_outlined, iconName: 'reports', route: '/report-repository'),
      ];
    } else if (userRole.contains('project')) {
      items = const [
        _NavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, iconName: 'dashboard', route: '/dashboard'),
        _NavItem(label: 'Projects', icon: Icons.folder_outlined, iconName: 'projects', route: '/projects'),
        _NavItem(label: 'Sprints', icon: Icons.timer_outlined, iconName: 'sprints', route: '/sprints'),
        _NavItem(label: 'Repository', icon: Icons.folder_outlined, iconName: 'repository', route: '/repository'),
        _NavItem(label: 'Reports', icon: Icons.assessment_outlined, iconName: 'reports', route: '/report-repository'),
      ];
    } else if (userRole.contains('delivery')) {
      items = const [
        _NavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, iconName: 'dashboard', route: '/dashboard'),
        _NavItem(label: 'Projects', icon: Icons.folder_outlined, iconName: 'projects', route: '/projects'),
        _NavItem(label: 'Sprints', icon: Icons.timer_outlined, iconName: 'sprints', route: '/sprints'),
        _NavItem(label: 'Repository', icon: Icons.folder_outlined, iconName: 'repository', route: '/repository'),
        _NavItem(label: 'Reports', icon: Icons.assessment_outlined, iconName: 'reports', route: '/report-repository'),
      ];
    } else if (userRole.contains('team')) {
      items = const [
        _NavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, iconName: 'dashboard', route: '/dashboard'),
        _NavItem(label: 'Projects', icon: Icons.folder_outlined, iconName: 'projects', route: '/projects'),
        _NavItem(label: 'Sprints', icon: Icons.timer_outlined, iconName: 'sprints', route: '/sprints'),
        _NavItem(label: 'Repository', icon: Icons.folder_outlined, iconName: 'repository', route: '/repository'),
        _NavItem(label: 'Reports', icon: Icons.assessment_outlined, iconName: 'reports', route: '/report-repository'),
      ];
    } else {
      // Default/fallback for unknown roles
      items = const [
        _NavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, iconName: 'dashboard', route: '/dashboard'),
        _NavItem(label: 'Projects', icon: Icons.folder_outlined, iconName: 'projects', route: '/projects'),
        _NavItem(label: 'Sprints', icon: Icons.timer_outlined, iconName: 'sprints', route: '/sprints'),
      ];
    }

    final roleSpecific = <_NavItem>[];
    if (authService.hasPermission('view_all_deliverables')) {
      roleSpecific.addAll([
        const _NavItem(label: 'Repository', icon: Icons.folder_outlined, iconName: 'repository', route: '/repository', requiredPermission: 'view_all_deliverables'),
        const _NavItem(label: 'Reports', icon: Icons.assessment_outlined, iconName: 'reports', route: '/report-repository', requiredPermission: 'view_all_deliverables'),
      ]);
    }

    items = [...items, ...roleSpecific];

    return items.where((item) {
      if (item.requiredPermission == null) return true;
      return authService.hasPermission(item.requiredPermission!);
    }).toList();
  }

  void _handleLogout(BuildContext context) async {
    final authService = AuthService();
    await authService.logout();
    if (context.mounted) {
      context.go('/login');
    }
  }

  Widget _buildThemeToggleButton(bool isDarkMode) {
    return FloatingActionButton(
      mini: true,
      onPressed: () {
        // TODO: Implement theme toggle
      },
      backgroundColor: Colors.white.withValues(alpha: 0.9),
      child: Icon(
        isDarkMode ? Icons.light_mode : Icons.dark_mode,
        color: isDarkMode ? Colors.black : Colors.black87,
        size: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final routeLocation = GoRouterState.of(context).uri.path;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
          backgroundColor: Colors.black,
          child: Column(
            children: [
              // Drawer header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0xFF333333),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Image.network(
                      'https://raw.githubusercontent.com/Khonology2/Module4/Busisiwe/frontend/assets/images/flownet_logo.png',
                      height: 32,
                      width: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Flow-Space',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.white),
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
        final sidebarSubtleText = isDarkMode ? Colors.white70 : Colors.black87;
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
            leading: Icon(
              item.icon,
              color: active ? sidebarTextColor : sidebarSubtleText,
              size: 20,
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
    final Color activeColor = isDarkMode ? Colors.white : Colors.black;
    final Color inactiveColor = isDarkMode ? Colors.white70 : Colors.black54;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: active ? activeColor.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          item.icon,
          color: active ? activeColor : inactiveColor,
          size: 20,
        ),
        title: Text(
          item.label,
          style: TextStyle(
            color: active ? activeColor : inactiveColor,
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        onTap: () => context.go(item.route),
      ),
    );
  }

  Widget _buildDesktopFooterItem({
    required String label,
    required String iconName,
    required IconData fallbackIcon,
    String? route,
    VoidCallback? onTap,
    required String currentRoute,
    required Color textColor,
  }) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool active = route != null && currentRoute.startsWith(route);
    final Color activeColor = isDarkMode ? Colors.white : Colors.black;
    final Color inactiveColor = isDarkMode ? Colors.white70 : Colors.black54;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      decoration: BoxDecoration(
        color: active ? activeColor.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          fallbackIcon,
          color: active ? activeColor : inactiveColor,
          size: 18,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: active ? activeColor : inactiveColor,
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        onTap: onTap ?? (route != null ? () => context.go(route) : null),
      ),
    );
  }
}
