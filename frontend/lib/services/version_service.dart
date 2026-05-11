import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
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
      // On web, use HTTP with a cache-busting query to ensure latest asset
      // after pull/hot-reload cycles.
      final String rawJson;
      if (kIsWeb) {
        // Use absolute URL to prevent double assets prefix
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
      // Fallback to generated version when asset is missing/unreadable.
    }

    _cachedVersionInfo = VersionControl.getVersionInfo();
    return _cachedVersionInfo!;
  }

  static Map<String, dynamic> getVersionDetails() {
    if (_cachedVersionInfo != null) {
      return _cachedVersionInfo!;
    }
    return VersionControl.getVersionInfo();
  }

  static String getLatestCommitTooltip(Map<String, dynamic> versionInfo) {
    final commits = versionInfo['commits'];
    if (commits is List && commits.isNotEmpty) {
      final latest = commits.first;
      if (latest is Map) {
        final author = latest['author']?.toString().trim();
        final message = latest['message']?.toString().trim();
        if ((author != null && author.isNotEmpty) &&
            (message != null && message.isNotEmpty)) {
          return 'Latest commit by @$author\n$message';
        }
      }
    }
    return 'No recent commits available';
  }
  
  static String getCurrentVersion() {
    if (_cachedVersionInfo != null && _cachedVersionInfo!['version'] != null) {
      return _cachedVersionInfo!['version'].toString();
    }
    return VersionControl.generateVersionNumber();
  }

  static void clearCachedVersion() {
    _cachedVersionInfo = null;
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
