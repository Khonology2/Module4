import 'package:flutter/foundation.dart';

class Environment {
  // App Configuration
  static const String appName = 'FlowSpace';
  static const String appVersion = '1.0.0';
  static const String appDescription =
      'A social learning platform built with Flutter';

  // FINAL FIX: HARDCODED CORRECT URL - NO LOGIC, NO DETECTION
  static String get apiBaseUrl {
    return "https://flow-space.onrender.com/api/v1";
  }

  // Environment detection
  static bool get isWeb => kIsWeb;
  static bool get isRenderDeployed => 
      isWeb && !Uri.base.toString().contains('localhost');

  // Debug information
  static String get environmentInfo {
    return '''
Environment Info:
- App Name: $appName
- Version: $appVersion
- Is Web: $isWeb
- Is Render Deployed: $isRenderDeployed
- API Base URL: $apiBaseUrl
- Current URL: ${Uri.base.toString()}
''';
  }
}
