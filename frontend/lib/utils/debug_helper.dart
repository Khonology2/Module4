import 'package:flutter/foundation.dart';
import '../config/environment.dart';

class DebugHelper {
  static void logEnvironmentInfo() {
    if (kDebugMode) {
      debugPrint('=== ENVIRONMENT DEBUG INFO ===');
      debugPrint('API Base URL: ${Environment.apiBaseUrl}');
      debugPrint('Debug Mode: ${Environment.debugMode}');
      debugPrint('Is Production: ${Environment.isProduction}');
      debugPrint('Is Render Deployed: ${Environment.isRenderDeployed}');
      debugPrint('Current Host: ${Uri.base.host}');
      debugPrint('Current URL: ${Uri.base.toString()}');
      debugPrint('==============================');
    }
  }
  
  static void logApiCall(String method, String endpoint) {
    if (kDebugMode) {
      debugPrint('🌐 API $method to: ${Environment.apiBaseUrl}$endpoint');
    }
  }
}
