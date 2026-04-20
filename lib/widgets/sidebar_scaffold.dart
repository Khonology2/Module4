import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/flownet_theme.dart';
import '../services/auth_service.dart';
import '../services/version_service.dart';
import '../models/user_role.dart';
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
  /// Client portal: solid accent for active nav row (#C10D00).
  static const Color _clientReviewerActiveRed = Color(0xFFC10D00);
  static const String _clientPortalSidebarLogoExpanded =
      'assets/Icons/khono.png';
  static const String _sidebarDiscLogo = 'assets/Icons/Red_Khono_Discs.png';

  double _logoSizeFor(double screenWidth) {
    // Responsive "breakpoints" so the logo stays readable on all widths.
    final expanded = screenWidth >= 1024 ? _logoExpandedSize : 56.0;
    final collapsed = screenWidth >= 1024 ? _logoMinCollapsedSize : 40.0;
    return _collapsed ? collapsed : expanded;
  }

  /// Merged from `origin/Busisiwe`: role-based nav. AI stays FAB-only (not duplicated here).
  /// Sprint route uses `/sprint-console` (matches [main] go_router). Client reviewer routes
  /// match pre-Busisiwe behavior so dashboards stay consistent.
  List<_NavItem> get _navItems {
    final authService = AuthService();
    final currentUser = authService.currentUser;
    final userRole = currentUser != null
        ? currentUser.role.toString().toLowerCase()
        : '';

    if (authService.isClientUser) {
      const crItems = <_NavItem>[
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
      ];
      // Full nav for client portal (reference UI); route guards enforce access.
      return crItems;
    }

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

    final List<_NavItem> roleSpecificItems = [];

    if (userRole.contains('admin') || userRole.contains('system')) {
      roleSpecificItems.addAll([
        const _NavItem(
          label: 'Sprints',
          icon: Icons.timer_outlined,
          iconName: 'sprints',
          route: '/sprint-console',
          requiredPermission: 'view_sprints',
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
      ]);
    } else if (userRole.contains('delivery') || userRole.contains('project')) {
      roleSpecificItems.addAll([
        const _NavItem(
          label: 'Sprints',
          icon: Icons.timer_outlined,
          iconName: 'sprints',
          route: '/sprint-console',
          requiredPermission: 'view_sprints',
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
      ]);
    } else if (userRole.contains('client')) {
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
    } else {
      // team_member and other roles: same extras as delivery (gated by permissions below)
      roleSpecificItems.addAll([
        const _NavItem(
          label: 'Sprints',
          icon: Icons.timer_outlined,
          iconName: 'sprints',
          route: '/sprint-console',
          requiredPermission: 'view_sprints',
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
      ]);
    }

    final combinedItems = [...allItems, ...roleSpecificItems];

    return combinedItems.where((item) {
      if (item.requiredPermission == 'HIDE_FROM_SIDEBAR') return false;

      if (currentUser?.role == UserRole.client &&
          (item.label == 'Projects' || item.label == 'Deliverables')) {
        return false;
      }

      if (authService.isClient) {
        if (item.route == '/projects' ||
            item.route == '/sprint-console' ||
            item.route == '/deliverables-overview') {
          return false;
        }
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
      final topState = GoRouter.maybeOf(context)?.state;
      if (topState != null && topState.matchedLocation.isNotEmpty) {
        routeLocation = topState.matchedLocation;
      } else {
        final router = GoRouter.maybeOf(context);
        final uri = router?.routeInformationProvider.value.uri;
        if (uri != null) {
          if (uri.path.isNotEmpty && uri.path != '/') {
            routeLocation = uri.path;
          } else if (uri.hasFragment) {
            final frag = uri.fragment;
            routeLocation = frag.startsWith('/') ? frag : '/$frag';
          } else {
            routeLocation = uri.path;
          }
        } else {
          routeLocation = ModalRoute.of(context)?.settings.name ?? '/';
        }
      }
    } catch (_) {
      routeLocation = ModalRoute.of(context)?.settings.name ?? '/';
    }
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final screenWidth = MediaQuery.of(context).size.width;
    final logoSize = _logoSizeFor(screenWidth);
    final isClientPortal = AuthService().isClientUser;

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
                          // Header: client portal = centered wordmark + subtitle; collapsed = short mark
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 12,
                              right: 12,
                              top: 24,
                              bottom: 16,
                            ),
                            child: isClientPortal && !_collapsed
                                ? SizedBox(
                                    height: 100,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                            right: 36,
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Center(
                                                child: Material(
                                                  type: MaterialType
                                                      .transparency,
                                                  child: InkWell(
                                                    onTap: () => context
                                                        .go('/dashboard'),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    child: ConstrainedBox(
                                                      constraints:
                                                          const BoxConstraints(
                                                        maxWidth: 232,
                                                      ),
                                                      child: Image.asset(
                                                        _clientPortalSidebarLogoExpanded,
                                                        height: screenWidth >=
                                                                1024
                                                            ? 40
                                                            : 34,
                                                        fit: BoxFit.contain,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                'Welcome to Deliverable & Sprint Sign-Off Hub',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color:
                                                      FlownetColors.pureWhite,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w400,
                                                  height: 1.25,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: IconButton(
                                            onPressed: _toggleSidebar,
                                            padding: EdgeInsets.zero,
                                            constraints:
                                                const BoxConstraints(),
                                            icon: Icon(
                                              _collapsed
                                                  ? Icons.chevron_right
                                                  : Icons.chevron_left,
                                              color:
                                                  FlownetColors.textSecondary,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : SizedBox(
                                    height: logoSize,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Material(
                                          type: MaterialType.transparency,
                                          child: InkWell(
                                            onTap: isClientPortal && _collapsed
                                                ? _toggleSidebar
                                                : () =>
                                                    context.go('/dashboard'),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Padding(
                                              padding: const EdgeInsets.all(6),
                                              child: isClientPortal &&
                                                      _collapsed
                                                  ? Tooltip(
                                                      message: 'Expand sidebar',
                                                      waitDuration:
                                                          const Duration(
                                                        milliseconds: 400,
                                                      ),
                                                      child: Image.asset(
                                                        _sidebarDiscLogo,
                                                        width: logoSize,
                                                        height: logoSize,
                                                        fit: BoxFit.contain,
                                                      ),
                                                    )
                                                  : Image.asset(
                                                      _sidebarDiscLogo,
                                                      width: logoSize,
                                                      height: logoSize,
                                                      fit: BoxFit.contain,
                                                    ),
                                            ),
                                          ),
                                        ),
                                        if (!(isClientPortal && _collapsed))
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: IconButton(
                                              onPressed: _toggleSidebar,
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              icon: Icon(
                                                _collapsed
                                                    ? Icons.chevron_right
                                                    : Icons.chevron_left,
                                                color: FlownetColors
                                                    .textSecondary,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                          ),
                          // Navigation items
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              itemCount: _navItems.length,
                              itemExtent: 56,
                              cacheExtent: 200,
                              addAutomaticKeepAlives: true,
                              itemBuilder: (context, index) {
                                final item = _navItems[index];
                                final active =
                                    routeLocation.startsWith(item.route);
                                final cr = isClientPortal;
                                final activeBg = cr && active
                                    ? _clientReviewerActiveRed
                                    : active
                                        ? Colors.white.withAlpha(
                                            (0.08 * 255).round(),
                                          )
                                        : Colors.transparent;
                                final iconColor = cr
                                    ? FlownetColors.pureWhite
                                    : active
                                        ? FlownetColors.pureWhite
                                        : FlownetColors.textSecondary;
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: activeBg,
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
                                                color: iconColor,
                                              ),
                                            ),
                                            if (!_collapsed) ...[
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  item.label,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: cr && active
                                                        ? FontWeight.w600
                                                        : FontWeight.w500,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                          if (isClientPortal) ...[
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                            if (_collapsed)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Column(
                                  children: [
                                    Tooltip(
                                      message: 'Account Profile',
                                      child: IconButton(
                                        onPressed: () =>
                                            context.go('/profile'),
                                        icon: AppIcons.accountProfileBadge(
                                          size: 26,
                                        ),
                                      ),
                                    ),
                                    Tooltip(
                                      message: 'Logout',
                                      child: IconButton(
                                        onPressed: () =>
                                            _handleLogout(context),
                                        icon: AppIcons.getIconWidget(
                                          'logout',
                                          fallbackIcon: Icons.logout,
                                          isActive: true,
                                          size: 26,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              _buildClientReviewerAccountRow(),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 8),
                                child: _buildClientReviewerLogoutRow(),
                              ),
                            ],
                            _buildClientReviewerVersionPill(),
                          ] else ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                              child: _buildLogoutButton(),
                            ),
                            SidebarVersionDisplay(
                              isSidebarCollapsed: _collapsed,
                            ),
                          ],
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
          title: isClientPortal
              ? Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () => context.go('/dashboard'),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Image.asset(
                        _clientPortalSidebarLogoExpanded,
                        height: 26,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                )
              : Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () => context.go('/dashboard'),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Image.asset(
                        _sidebarDiscLogo,
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
            if (!isClientPortal) ...[
              IconButton(
                onPressed: () => context.go('/profile'),
                tooltip: 'Profile',
                padding: const EdgeInsets.all(4),
                constraints:
                    const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: Builder(
                  builder: (context) {
                    final path = GoRouterState.of(context).uri.path;
                    final onProfile =
                        path == '/profile' || path.startsWith('/profile/');
                    return InteractiveHeaderIcon(
                      inactiveAsset: AppIcons.accountProfileBadgeAsset,
                      activeAsset: AppIcons.accountProfileBadgeAsset,
                      routeActive: onProfile,
                      size: 40,
                    );
                  },
                ),
              ),
              IconButton(
                onPressed: () => context.go('/settings'),
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
                color: FlownetColors.pureWhite,
                iconSize: 20,
              ),
            ],
            const NotificationCenterWidget(
              showLabel: false,
              showBackground: false,
              circularLightButton: true,
            ),
            if (isClientPortal)
              IconButton(
                onPressed: () => context.go('/settings'),
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
                color: FlownetColors.pureWhite,
                iconSize: 20,
              ),
            if (!isClientPortal) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => context.go('/profile?mode=view'),
                tooltip: 'Account',
                icon: AppIcons.accountProfileBadge(size: 26),
              ),
            ],
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
                if (isClientPortal)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          context.go('/dashboard');
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          children: [
                            Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 260,
                                ),
                                child: Image.asset(
                                  _clientPortalSidebarLogoExpanded,
                                  height: 40,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Welcome to Deliverable & Sprint Sign-Off Hub',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: FlownetColors.pureWhite,
                                fontSize: 11,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
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
                              _sidebarDiscLogo,
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
                    itemExtent: 56,
                    cacheExtent: 200,
                    addAutomaticKeepAlives: true,
                    itemBuilder: (context, index) {
                      final item = _navItems[index];
                      final active = routeLocation.startsWith(item.route);
                      final cr = isClientPortal;
                      if (cr) {
                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? _clientReviewerActiveRed
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: AppIcons.getIconWidget(
                              item.iconName,
                              fallbackIcon: item.icon,
                              isActive: active,
                              size: 24,
                              color: FlownetColors.pureWhite,
                            ),
                            title: Text(
                              item.label,
                              style: TextStyle(
                                color: FlownetColors.pureWhite,
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.w500,
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
                      }
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? FlownetColors.crimsonRed
                                  .withAlpha((0.1 * 255).round())
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
                if (isClientPortal) ...[
                  const Divider(
                    height: 1,
                    color: FlownetColors.slate,
                  ),
                  ListTile(
                    leading: AppIcons.accountProfileBadge(size: 28),
                    title: const Text(
                      'Account Profile',
                      style: TextStyle(color: FlownetColors.pureWhite),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/profile');
                    },
                  ),
                  ListTile(
                    leading: AppIcons.getIconWidget(
                      'logout',
                      fallbackIcon: Icons.logout,
                      isActive: true,
                      size: 28,
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
                  _buildClientReviewerVersionPill(),
                ] else
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ListTile(
                      leading: AppIcons.getIconWidget(
                        'logout',
                        fallbackIcon: Icons.logout,
                        isActive: true,
                        size: 28,
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

  Widget _buildClientReviewerAccountRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/profile'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                AppIcons.accountProfileBadge(size: 26),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Account Profile',
                    style: TextStyle(
                      color: FlownetColors.pureWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClientReviewerLogoutRow() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleLogout(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              AppIcons.getIconWidget(
                'logout',
                fallbackIcon: Icons.logout,
                isActive: true,
                size: 26,
              ),
              const SizedBox(width: 12),
              const Text(
                'Logout',
                style: TextStyle(
                  color: FlownetColors.pureWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClientReviewerVersionPill() {
    if (_collapsed) return const SizedBox.shrink();
    final version =
        VersionService.getVersionDetails()['version'].toString().trim();
    final label =
        version.toUpperCase().startsWith('VER') ? version : 'Ver $version';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 12, right: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.65),
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
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
