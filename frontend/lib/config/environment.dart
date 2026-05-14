class Environment {
  // App Configuration
  static const String appName = 'Khonology';
  static const String appVersion = '1.0.0';
  static const String appDescription =
      'A social learning platform built with Flutter';

  // API Configuration (supports --dart-define=API_BASE_URL=...)
  static String? _overrideApiBaseUrl;

  static void setOverrideApiBaseUrl(String? url) {
    final trimmed = url?.trim() ?? '';
    _overrideApiBaseUrl = trimmed.isEmpty ? null : trimmed;
  }

  static String get apiBaseUrl {
    final overridden = _overrideApiBaseUrl;
    if (overridden != null && overridden.isNotEmpty) {
      return overridden;
    }
    // Check for build-time API base URL first
    const baseUrlFromEnv = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    );

    // Check for production flag
    const isProduction =
        bool.fromEnvironment('IS_PRODUCTION', defaultValue: false);

    // Use build-time URL if provided
    if (baseUrlFromEnv.trim().isNotEmpty) {
      return baseUrlFromEnv;
    }

    // Explicit localhost/browser-local should always use local backend.
    if (isLocalDevelopment) {
      return 'http://localhost:8000/api/v1';
    }

    // Fallback to the deployed backend for production-like hosts.
    if (isProduction || isRenderDeployed) {
      return 'https://flow-space.onrender.com/api/v1';
    }
    return 'http://localhost:8000/api/v1';
  }

  // Base URL without version for endpoints that already include version
  static String get baseUrlWithoutVersion {
    final baseUrl = apiBaseUrl;
    if (baseUrl.endsWith('/api/v1')) {
      return baseUrl.replaceAll('/api/v1', '');
    }
    return baseUrl;
  }

  static const int apiTimeout = 30000;

  // Feature Flags
  static const bool enableAnalytics = true;
  static const bool enableCrashReporting = true;
  static const bool enablePushNotifications = true;

  // Development Settings
  static const bool debugMode = bool.fromEnvironment(
    'DEBUG_MODE',
    defaultValue: true,
  );
  static const String logLevel = 'debug';

  // Environment-specific configurations
  static bool get isProduction => !debugMode;
  static bool get isDevelopment => debugMode;

  // Check if running on Render.com or other production environments
  static bool get isRenderDeployed {
    try {
      final uri = Uri.base;
      final host = uri.host.toLowerCase();
      if (host.isEmpty) return false;
      if (uri.scheme != 'http' && uri.scheme != 'https') return false;
      if (host.contains('localhost') || host.contains('127.0.0.1')) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  // Check if running in local development mode
  static bool get isLocalDevelopment {
    try {
      final uri = Uri.base;
      return uri.host.contains('localhost') || uri.host.contains('127.0.0.1');
    } catch (e) {
      return true; // Assume local if can't detect
    }
  }
}
