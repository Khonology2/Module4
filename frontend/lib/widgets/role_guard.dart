import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';

class _RouteHistory {
  static String _currentPath(BuildContext context) {
    try {
      final router = GoRouter.maybeOf(context);
      final uri = router?.routeInformationProvider.value.uri;
      if (uri != null) return uri.path;
    } catch (_) {}
    return ModalRoute.of(context)?.settings.name?.toString() ?? '/';
  }

  static void markAllowed(BuildContext context) {
    _currentPath(context);
  }
}

class _RedirectToDashboard extends StatelessWidget {
  const _RedirectToDashboard();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentPath = _RouteHistory._currentPath(context);
      if (currentPath != '/dashboard') {
        GoRouter.of(context).go('/dashboard');
      }
    });
    return const SizedBox.shrink();
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

    // Keep users on dashboard instead of rendering access-denied screens.
    return const _RedirectToDashboard();
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

    return const _RedirectToDashboard();
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
