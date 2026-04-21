import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../theme/flownet_theme.dart';

class _RouteHistory {
  static String? lastAllowedPath;

  static String _currentPath(BuildContext context) {
    try {
      final router = GoRouter.maybeOf(context);
      final uri = router?.routeInformationProvider.value.uri;
      if (uri != null) return uri.path;
    } catch (_) {}
    return ModalRoute.of(context)?.settings.name?.toString() ?? '/';
  }

  static void markAllowed(BuildContext context) {
    final path = _currentPath(context);
    if (path.isNotEmpty) {
      lastAllowedPath = path;
    }
  }

  static void goBack(BuildContext context) {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    final fallback = (lastAllowedPath != null && lastAllowedPath!.isNotEmpty)
        ? lastAllowedPath!
        : '/dashboard';
    GoRouter.of(context).go(fallback);
  }
}

class RoleGuard extends StatelessWidget {
  final Widget child;
  final String requiredPermission;
  final Widget? fallback;
  final bool showUnauthorizedMessage;

  const RoleGuard({
    super.key,
    required this.child,
    required this.requiredPermission,
    this.fallback,
    this.showUnauthorizedMessage = true,
  });

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    if (authService.hasPermission(requiredPermission)) {
      _RouteHistory.markAllowed(context);
      return child;
    }

    if (fallback != null) {
      return fallback!;
    }

    if (showUnauthorizedMessage) {
      return _buildUnauthorizedWidget(context);
    }

    return const SizedBox.shrink();
  }

  Widget _buildUnauthorizedWidget(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock_outline,
            size: 64,
            color: FlownetColors.coolGray,
          ),
          const SizedBox(height: 16),
          Text(
            'Access Denied',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: FlownetColors.pureWhite,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You don\'t have permission to access this feature.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: FlownetColors.coolGray,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _RouteHistory.goBack(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: FlownetColors.electricBlue,
              foregroundColor: FlownetColors.pureWhite,
            ),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
}

class RouteGuard extends StatelessWidget {
  final String route;
  final Widget child;

  const RouteGuard({
    super.key,
    required this.route,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    if (authService.canAccessRoute(route)) {
      _RouteHistory.markAllowed(context);
      return child;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.block,
            size: 64,
            color: FlownetColors.crimsonRed,
          ),
          const SizedBox(height: 16),
          Text(
            'Route Access Denied',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: FlownetColors.pureWhite,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your role does not have access to this page.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: FlownetColors.coolGray,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _RouteHistory.goBack(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: FlownetColors.electricBlue,
              foregroundColor: FlownetColors.pureWhite,
            ),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
}

class PermissionBuilder extends StatelessWidget {
  final String permission;
  final Widget Function(BuildContext context) builder;
  final Widget? fallback;

  const PermissionBuilder({
    super.key,
    required this.permission,
    required this.builder,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    if (authService.hasPermission(permission)) {
      return builder(context);
    }

    return fallback ?? const SizedBox.shrink();
  }
}

class RoleBuilder extends StatelessWidget {
  final List<String> allowedRoles;
  final Widget Function(BuildContext context) builder;
  final Widget? fallback;

  const RoleBuilder({
    super.key,
    required this.allowedRoles,
    required this.builder,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final currentRole = authService.currentUserRole?.name;
    
    if (currentRole != null && allowedRoles.contains(currentRole)) {
      return builder(context);
    }

    return fallback ?? const SizedBox.shrink();
  }
}
