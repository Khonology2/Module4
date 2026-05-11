import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../utils/version_control.dart';

class VersionService {
  static Map<String, dynamic>? _cachedVersionInfo;

  static Future<Map<String, dynamic>> getVersionDetailsFromAsset({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedVersionInfo != null) {
      return _cachedVersionInfo!;
    }

    try {
      final String rawJson;
      if (kIsWeb) {
        final baseUrl = Uri.base.origin;
        final uri = Uri.parse(
          '$baseUrl/assets/data/version.json?v=${DateTime.now().millisecondsSinceEpoch}',
        );
        final response = await http.get(uri);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          rawJson = response.body;
        } else {
          rawJson = await rootBundle.loadString('assets/data/version.json');
        }
      } else {
        rawJson = await rootBundle.loadString('assets/data/version.json');
      }

      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        _cachedVersionInfo = decoded;
        return decoded;
      }
    } catch (_) {
      // Fall back to generated version information when the asset is unavailable.
    }

    _cachedVersionInfo = VersionControl.getVersionInfo();
    return _cachedVersionInfo!;
  }

  static Map<String, dynamic> getVersionDetails() {
    return VersionControl.getVersionInfo();
  }
  
  static String getCurrentVersion() {
    return VersionControl.generateVersionNumber();
  }
  
  static String getEnvironment() {
    return VersionControl.environment;
  }
  
  static String getFormattedVersionInfo() {
    return VersionControl.getFormattedVersionInfo();
  }
  
  static bool isProductionEnvironment() {
    return VersionControl.environment == 'PROD';
  }
  
  static bool isStagingEnvironment() {
    return VersionControl.environment == 'SIT' || VersionControl.environment == 'UAT';
  }
  
  static bool isDevelopmentEnvironment() {
    return VersionControl.environment == 'DEV';
  }
}
