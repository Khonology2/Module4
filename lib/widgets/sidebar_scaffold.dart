import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/flownet_theme.dart';
import '../services/auth_service.dart';
import '../utils/app_icons.dart';
import 'background_image.dart';
import 'notification_center_widget.dart';
import 'interactive_header_icon.dart';
import 'sidebar_version_display.dart';
import 'ai_assistant_fab_button.dart';

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
  bool _collapsed = false;
  static const double _sidebarWidth = 280;
  static const double _collapsedWidth = 80;
  static const double _logoMinCollapsedSize = 44;
  static const double _logoExpandedSize = 64;

  double _logoSizeFor(double screenWidth) {
    // Responsive "breakpoints" so the logo stays readable on all widths.
    final expanded = screenWidth >= 1024 ? _logoExpandedSize : 56.0;
    final collapsed = screenWidth >= 1024 ? _logoMinCollapsedSize : 40.0;
    return _collapsed ? collapsed : expanded;
  }

  List<_NavItem> get _navItems {
    final authService = AuthService();
    final allItems = [
      // Work-focused items only
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
      const _NavItem(
        label: 'Role Management',
        icon: Icons.admin_panel_settings_outlined,
        iconName: 'role_management',
        route: '/role-management',
        requiredPermission: 'manage_users',
      ),
      const _NavItem(
        label: 'Settings', // kept for potential use outside sidebar
        icon: Icons.settings_outlined,
        iconName: 'settings',
        route: '/settings',
        requiredPermission: 'HIDE_FROM_SIDEBAR',
      ),
    ];

    // Filter items based on user permissions
    return allItems.where((item) {
      if (authService.isClientReviewer || authService.isClient) {
        if (item.route == '/projects' ||
            item.route == '/sprint-console' ||
            item.route == '/deliverables-overview') {
          return false;
        }
      }
      // Special flag: hide from sidebar even if user has permission
      if (item.requiredPermission == 'HIDE_FROM_SIDEBAR') return false;
      if (item.requiredPermission == null) return true;
      return authService.hasPermission(item.requiredPermission!);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _restoreSidebarState();
  }

  void _restoreSidebarState() {
    // Restore sidebar state from SharedPreferences or other storage
    // For now, we'll use a default state
    _collapsed = false;
  }

  void _persistSidebarState() {
    // Save sidebar state to SharedPreferences or other storage
    // Implementation would go here
  }

  void _toggleSidebar() {
    setState(() {
      _collapsed = !_collapsed;
    });
    _persistSidebarState();
  }

  /// Timeline stacks the AI control with its own FAB; avoid duplicate controls.
  bool _timelineHostsAiFabColumn(String path) {
    if (path == '/timeline') return true;
    if (path.startsWith('/timeline/')) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
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
    final screenWidth = MediaQuery.of(context).size.width;
    final logoSize = _logoSizeFor(screenWidth);

    if (isDesktop) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: _timelineHostsAiFabColumn(routeLocation)
            ? null
            : const AiAssistantFabButton(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: BackgroundImage(
          child: Row(
            children: [
              // Sidebar with glassmorphism styling (Busisiwe branch look)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _collapsed ? _collapsedWidth : _sidebarWidth,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border.all(
                    color: Colors.white.withAlpha((0.1 * 255).round()),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    child: Column(
                        children: [
                          // Header with logo and collapse toggle
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 12, right: 12, top: 24, bottom: 16,),
                            child: SizedBox(
                              height: logoSize,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Centered logo (universal home navigation)
                                  Material(
                                    type: MaterialType.transparency,
                                    child: InkWell(
                                      onTap: () => context.go('/dashboard'),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Image.asset(
                                          'assets/Icons/Red_Khono_Discs.png',
                                          width: logoSize,
                                          height: logoSize,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Collapse toggle (kept intact, aligned right)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: IconButton(
                                      onPressed: _toggleSidebar,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: Icon(
                                        _collapsed
                                            ? Icons.chevron_right
                                            : Icons.chevron_left,
                                        color: FlownetColors.textSecondary,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Navigation items (pill-style highlight like reference UI)
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              itemCount: _navItems.length,
                              itemExtent: 56, // Match Busisiwe sidebar height
                              cacheExtent: 200,
                              addAutomaticKeepAlives: true,
                              itemBuilder: (context, index) {
                                final item = _navItems[index];
                                final active =
                                    routeLocation.startsWith(item.route);
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    // Active item: soft pill-shaped dark highlight, no red border
                                    color: active
                                        ? Colors.white.withAlpha(
                                            (0.08 * 255).round(),
                                          )
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        if (!routeLocation
                                            .startsWith(item.route)) {
                                          context.go(item.route);
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: _collapsed ? 4 : 16,
                                          vertical: 12,
                                        ),
                                        child: _collapsed
                                            ? Center(
                                                child: SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: AppIcons.getIconWidget(
                                                    item.iconName,
                                                    fallbackIcon: item.icon,
                                                    isActive: active,
                                                    size: 20,
                                                    color: active
                                                        ? FlownetColors.pureWhite
                                                        : FlownetColors
                                                            .textSecondary,
                                                  ),
                                                ),
                                              )
                                            : Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.start,
                                                children: [
                                                  SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child:
                                                        AppIcons.getIconWidget(
                                                      item.iconName,
                                                      fallbackIcon: item.icon,
                                                      isActive: active,
                                                      size: 20,
                                                      color: active
                                                          ? FlownetColors
                                                              .pureWhite
                                                          : FlownetColors
                                                              .textSecondary,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      item.label,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: _buildLogoutButton(),
                          ),
                          SidebarVersionDisplay(
                            isSidebarCollapsed: _collapsed,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Container(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      Expanded(child: widget.child),
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
        appBar: AppBar(
          title: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => context.go('/dashboard'),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Image.asset(
                  'assets/Icons/Red_Khono_Discs.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          centerTitle: false,
          actions: [
            if (routeLocation != '/dashboard')
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Back',
              ),
            // Profile (same branded header assets + hover as role dashboard)
            IconButton(
              onPressed: () => context.go('/profile'),
              tooltip: 'Profile',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: Builder(
                builder: (context) {
                  final path = GoRouterState.of(context).uri.path;
                  final onProfile =
                      path == '/profile' || path.startsWith('/profile/');
                  return InteractiveHeaderIcon(
                    inactiveAsset: 'assets/Icons/header_profile_inactive.png',
                    activeAsset: 'assets/Icons/header_profile_active.png',
                    routeActive: onProfile,
                    size: 40,
                  );
                },
              ),
            ),
            // Settings Icon
            IconButton(
              onPressed: () => context.go('/settings'),
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              color: FlownetColors.pureWhite,
              iconSize: 20,
            ),
            const NotificationCenterWidget(
              showLabel: false,
              showBackground: false,
              circularLightButton: true,
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => context.go('/profile?mode=view'),
              icon: const Icon(Icons.account_circle_outlined),
              tooltip: 'Account',
              color: FlownetColors.pureWhite,
              iconSize: 22,
            ),
          ],
        ),
        body: BackgroundImage(
          child: widget.child,
        ),
        floatingActionButton: _timelineHostsAiFabColumn(routeLocation)
            ? null
            : const AiAssistantFabButton(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        drawer: Drawer(
          backgroundColor: FlownetColors.charcoalBlack,
          child: SafeArea(
            child: Column(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          context.go('/dashboard');
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Image.asset(
                            'assets/Icons/Red_Khono_Discs.png',
                            width: 72,
                            height: 72,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Divider(color: FlownetColors.slate),
                Expanded(
                  child: ListView.builder(
                    itemCount: _navItems.length,
                    itemExtent: 56, // Fixed height for better performance
                    cacheExtent: 200, // Cache more items for smoother scrolling
                    addAutomaticKeepAlives: true, // Keep state of list items
                    itemBuilder: (context, index) {
                      final item = _navItems[index];
                      final active = routeLocation.startsWith(item.route);
                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2,),
                        decoration: BoxDecoration(
                          color: active
                              ? FlownetColors.crimsonRed.withAlpha((0.1 * 255).round())
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          border: active
                              ? const Border(
                                  left: BorderSide(
                                    color: FlownetColors.crimsonRed,
                                    width: 4,
                                  ),
                                )
                              : null,
                        ),
                        child: ListTile(
                          leading: AppIcons.getIconWidget(
                            item.iconName,
                            fallbackIcon: item.icon,
                            isActive: active,
                            size: 24,
                            color: active
                                ? FlownetColors.crimsonRed
                                : FlownetColors.coolGray,
                          ),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              color: active
                                  ? FlownetColors.crimsonRed
                                  : FlownetColors.pureWhite,
                              fontWeight: active
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            if (!routeLocation.startsWith(item.route)) {
                              context.go(item.route);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: const Icon(
                      Icons.logout,
                      color: FlownetColors.textSecondary,
                    ),
                    title: const Text(
                      'Logout',
                      style: TextStyle(color: FlownetColors.pureWhite),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _handleLogout(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Future<void> _handleLogout(BuildContext ctx) async {
    final router = GoRouter.of(ctx);
    await AuthService().signOut();
    if (!mounted) return;
    router.go('/');
  }

  /// Desktop sidebar logout: icon-only when collapsed (matches nav row height/spacing);
  /// full [TextButton.icon] when expanded (unchanged styling).
  Widget _buildLogoutButton() {
    final decoration = BoxDecoration(
      color: FlownetColors.crimsonRed.withAlpha((0.1 * 255).round()),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: FlownetColors.crimsonRed.withAlpha((0.3 * 255).round()),
        width: 1,
      ),
    );

    if (_collapsed) {
      return Tooltip(
        message: 'Logout',
        waitDuration: const Duration(milliseconds: 400),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _handleLogout(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 56,
                width: double.infinity,
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: decoration,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(
                    child: AppIcons.getIconWidget(
                      'logout',
                      fallbackIcon: Icons.logout,
                      isActive: true,
                      size: 20,
                      color: FlownetColors.crimsonRed,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: decoration,
      child: TextButton.icon(
        onPressed: () => _handleLogout(context),
        icon: AppIcons.getIconWidget(
          'logout',
          fallbackIcon: Icons.logout,
          isActive: true,
          size: 20,
          color: FlownetColors.crimsonRed,
        ),
        label: const Text(
          'Logout',
          style: TextStyle(
            color: FlownetColors.crimsonRed,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        ),
      ),
    );
  }
}
