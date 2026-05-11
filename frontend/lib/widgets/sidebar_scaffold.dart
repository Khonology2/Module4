// ignore_for_file: prefer_const_constructors, unused_import, unused_field

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/flownet_theme.dart';
import '../services/auth_service.dart';
import '../utils/app_icons.dart';
import 'background_image.dart';

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

    final List<_NavItem> items;

    if (isAdminLike) {
      items = const [
        _NavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, iconName: 'dashboard', route: '/dashboard'),
        _NavItem(label: 'Projects', icon: Icons.folder_outlined, iconName: 'projects', route: '/projects'),
        _NavItem(label: 'Sprints', icon: Icons.timer_outlined, iconName: 'sprints', route: '/sprints'),
        _NavItem(label: 'Deliverables', icon: Icons.assignment_outlined, iconName: 'deliverables', route: '/deliverables-overview'),
        _NavItem(label: 'Timeline', icon: Icons.calendar_today_outlined, iconName: 'timeline', route: '/timeline'),
        _NavItem(label: 'Approval Requests', icon: Icons.assignment_outlined, iconName: 'approval_requests', route: '/approval-requests'),
        _NavItem(label: 'Repository', icon: Icons.folder_outlined, iconName: 'repository', route: '/repository'),
        _NavItem(label: 'Reports', icon: Icons.assessment_outlined, iconName: 'reports', route: '/report-repository'),
        _NavItem(label: 'User Management', icon: Icons.admin_panel_settings_outlined, iconName: 'role_management', route: '/role-management'),
        _NavItem(label: 'FlowPilot', icon: Icons.smart_toy_outlined, iconName: 'ai_assistant', route: '/ai-assistant'),
      ];
    } else {
      final List<_NavItem> baseItems = [
        const _NavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, iconName: 'dashboard', route: '/dashboard'),
        const _NavItem(label: 'FlowPilot', icon: Icons.smart_toy_outlined, iconName: 'ai_assistant', route: '/ai-assistant'),
        const _NavItem(label: 'Projects', icon: Icons.folder_outlined, iconName: 'projects', route: '/projects'),
        const _NavItem(label: 'Sprints', icon: Icons.timer_outlined, iconName: 'sprints', route: '/sprint-console', requiredPermission: 'view_sprints'),
        const _NavItem(label: 'Deliverables', icon: Icons.assignment_outlined, iconName: 'deliverables', route: '/deliverables-overview'),
        const _NavItem(label: 'Timeline', icon: Icons.calendar_today_outlined, iconName: 'timeline', route: '/timeline'),
      ];

      final List<_NavItem> roleSpecific = [];

      if (userRole.contains('delivery') || userRole.contains('project')) {
        roleSpecific.addAll([
          const _NavItem(label: 'Approval Requests', icon: Icons.assignment_outlined, iconName: 'approval_requests', route: '/approval-requests', requiredPermission: 'view_approvals'),
          const _NavItem(label: 'Repository', icon: Icons.folder_outlined, iconName: 'repository', route: '/repository', requiredPermission: 'view_all_deliverables'),
          const _NavItem(label: 'Reports', icon: Icons.assessment_outlined, iconName: 'reports', route: '/report-repository', requiredPermission: 'view_all_deliverables'),
        ]);
      } else if (userRole.contains('client')) {
        roleSpecific.addAll([
          const _NavItem(label: 'Approval Requests', icon: Icons.assignment_outlined, iconName: 'approval_requests', route: '/approval-requests', requiredPermission: 'view_approvals'),
          const _NavItem(label: 'Repository', icon: Icons.folder_outlined, iconName: 'repository', route: '/repository', requiredPermission: 'view_all_deliverables'),
          const _NavItem(label: 'Reports', icon: Icons.assessment_outlined, iconName: 'reports', route: '/report-repository', requiredPermission: 'view_all_deliverables'),
        ]);
      }

      items = [...baseItems, ...roleSpecific];
    }

    final authService = AuthService();

    return items.where((item) {
      if (item.requiredPermission == null) return true;
      return authService.hasPermission(item.requiredPermission!);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final routeLocation = GoRouterState.of(context).uri.path;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _buildDesktopSidebar(routeLocation),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    return Scaffold(
      drawer: Drawer(
        child: _buildMobileNav(routeLocation),
      ),
      body: widget.child,
    );
  }

  Widget _buildMobileNav(String routeLocation) {
    return ListView.builder(
      itemCount: _navItems.length,
      itemBuilder: (context, index) {
        final item = _navItems[index];
        final active = routeLocation.startsWith(item.route);

        return ListTile(
          title: Text(item.label),
          selected: active,
          onTap: () {
            context.go(item.route);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildDesktopSidebar(String routeLocation) {
    return Container(
      width: _sidebarWidth,
      color: Colors.black,
      child: ListView.builder(
        itemCount: _navItems.length,
        itemBuilder: (context, index) {
          final item = _navItems[index];
          final active = routeLocation.startsWith(item.route);

          return ListTile(
            title: Text(item.label, style: TextStyle(color: Colors.white)),
            selected: active,
            onTap: () => context.go(item.route),
          );
        },
      ),
    );
  }

  Future<void> _handleLogout(BuildContext ctx) async {
    final router = GoRouter.of(ctx);
    await AuthService().signOut();
    if (!mounted) return;
    router.go('/');
  }
}
