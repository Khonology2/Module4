// ignore_for_file: prefer_single_quotes

class Environment {
  // App Configuration
  static const String appName = 'Khonology';
  static const String appVersion = '1.0.0';
  static const String appDescription =
      'A social learning platform built with Flutter';

  // API Configuration (supports --dart-define=API_BASE_URL=...)
  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3001/api/v1',
  );

  // Production fallback detection
  static String get apiBaseUrl {
    // Respect build-time API base URL first (local or deployed).
    if (_apiBaseUrl.trim().isNotEmpty) {
      return _apiBaseUrl;
    }

    // Fallback only if define is unexpectedly empty.
    if (isRenderDeployed) {
      return 'https://flow-space.onrender.com/api/v1';
    }
    return 'http://localhost:3001/api/v1';
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
    // Check if we're in a browser environment and not localhost
    try {
      final uri = Uri.base;
      return uri.host.contains('onrender.com') ||
          uri.host.contains('flownet.works');
    } catch (e) {
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
