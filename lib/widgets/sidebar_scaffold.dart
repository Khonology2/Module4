import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/flownet_theme.dart';
import '../services/auth_service.dart';
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
  bool _collapsed = false;
  static const double _sidebarWidth = 280;
  static const double _collapsedWidth = 80;

  // Navigation history tracking
  List<String> _navigationHistory = ['/dashboard'];
  int _historyIndex = 0;

  // Track navigation history
  void _updateNavigationHistory(String route) {
    if (_navigationHistory.isEmpty ||
        _navigationHistory[_historyIndex] != route) {
      // Remove any forward history when navigating to new route
      if (_historyIndex < _navigationHistory.length - 1) {
        _navigationHistory =
            _navigationHistory.take(_historyIndex + 1).toList();
      }

      setState(() {
        _navigationHistory.add(route);
        _historyIndex = _navigationHistory.length - 1;
      });
    }
  }

  List<_NavItem> get _navItems {
    final authService = AuthService();
    final currentUser = authService.currentUser;
    final userRole = currentUser != null 
        ? currentUser.role.toString().toLowerCase()
        : '';

    final bool includeSprints = userRole.contains('admin') ||
        userRole.contains('system') ||
        userRole.contains('delivery') ||
        userRole.contains('project');

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
      if (includeSprints)
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
        label: 'FlowPilot',
        icon: Icons.smart_toy_outlined,
        iconName: 'ai_assistant',
        route: '/ai-assistant',
        requiredPermission: null,
      ),
    ];

    // Role-specific items
    final List<_NavItem> roleSpecificItems = [];

    if (userRole.contains('admin') || userRole.contains('system')) {
      // Admin/System users get full access
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
        const _NavItem(
          label: 'Role Management',
          icon: Icons.admin_panel_settings_outlined,
          iconName: 'role_management',
          route: '/role-management',
          requiredPermission: 'manage_users',
        ),
        const _NavItem(
          label: 'Settings',
          icon: Icons.settings_outlined,
          iconName: 'settings',
          route: '/settings',
          requiredPermission: null,
        ),
      ]);
    } else if (userRole.contains('delivery') || userRole.contains('project')) {
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

    // Track navigation history
    _updateNavigationHistory(routeLocation);

    if (isDesktop) {
      return Scaffold(
        backgroundColor: Colors.transparent,
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
                            left: 12,
                            right: 12,
                            top: 24,
                            bottom: 16,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/Icons/Red_Khono_Discs.png',
                                width: _collapsed ? 28 : 64,
                                height: _collapsed ? 28 : 64,
                                fit: BoxFit.contain,
                              ),
                              if (!_collapsed) const SizedBox(width: 40),
                              if (!_collapsed)
                                IconButton(
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
                            ],
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
                                        horizontal: _collapsed ? 8 : 16,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: _collapsed
                                            ? MainAxisAlignment.center
                                            : MainAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: AppIcons.getIconWidget(
                                              item.iconName,
                                              fallbackIcon: item.icon,
                                              isActive: active,
                                              size: 20,
                                              color: active
                                                  ? FlownetColors.pureWhite
                                                  : FlownetColors.textSecondary,
                                            ),
                                          ),
                                          if (!_collapsed) ...[
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                item.label,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
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
        body: BackgroundImage(
          child: widget.child,
        ),
        drawer: Drawer(
          backgroundColor: FlownetColors.charcoalBlack,
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
                    const Expanded(
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
                      icon: const Icon(Icons.close, color: Colors.white),
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
              color: active ? Colors.white : FlownetColors.textSecondary,
            ),
            title: Text(
              item.label,
              style: TextStyle(
                color: active ? Colors.white : FlownetColors.textSecondary,
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

  Future<void> _handleLogout(BuildContext ctx) async {
    final router = GoRouter.of(ctx);
    await AuthService().signOut();
    if (!mounted) return;
    router.go('/');
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: FlownetColors.crimsonRed.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FlownetColors.crimsonRed.withAlpha((0.3 * 255).round()),
          width: 1,
        ),
      ),
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
