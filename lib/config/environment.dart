// ignore_for_file: prefer_single_quotes

class Environment {
  // App Configuration
  static const String appName = 'Khonology';
  static const String appVersion = '1.0.0';
  static const String appDescription =
      'A social learning platform built with Flutter';

  // API Configuration - Use const for production URL from build
  // Default uses 127.0.0.1 (not localhost): on Windows, "localhost" often resolves to
  // ::1 first while Node listens on IPv4 only, causing ~45s hangs until timeout.
  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: "http://127.0.0.1:3001/api/v1",
  );

  static const String _defaultDevApi =
      "http://127.0.0.1:3001/api/v1";

  // Production fallback detection
  static String get apiBaseUrl {
    // First try build-time variable
    if (_apiBaseUrl != _defaultDevApi) {
      return _apiBaseUrl;
    }

    // Fallback if deployed but build-time URL wasn't provided
    if (isRenderDeployed) {
      return "https://backend-532p.onrender.com/api/v1";
    }

    // Always use 127.0.0.1 for local API (not "localhost"). On many Windows setups
    // `localhost:3001` resolves via IPv6 or stalls while `127.0.0.1:3001` works. CORS
    // allows the Flutter web app at http://localhost:* to call http://127.0.0.1:3001.
    return _apiBaseUrl;
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
