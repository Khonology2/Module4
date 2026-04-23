import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config/environment_config.dart';
import '../utils/version_control.dart';

class EnvironmentService {
  static String _currentEnvironment = 'SIT';
  
  static String get currentEnvironment {
    if (kDebugMode) {
      return _currentEnvironment;
    }
    
    // In production, read from environment variable or config file
    final env = Platform.environment['FLUTTER_ENV'] ?? 'SIT';
    return env;
  }
  
  static String get baseUrl {
    return EnvironmentConfig.getBaseUrl(currentEnvironment);
  }
  
  static String get databaseUrl {
    return EnvironmentConfig.getDatabaseUrl(currentEnvironment);
  }
  
  static String get environmentDisplayName {
    return EnvironmentConfig.getEnvironmentDisplayName(currentEnvironment);
  }
  
  static Map<String, String> get currentConfig {
    return EnvironmentConfig.getCurrentConfig(currentEnvironment);
  }
  
  static bool get isDevelopment => currentEnvironment == 'DEV';
  static bool get isSIT => currentEnvironment == 'SIT';
  static bool get isUAT => currentEnvironment == 'UAT';
  static bool get isProduction => currentEnvironment == 'PROD';
  
  static void switchEnvironment(String environment) {
    _currentEnvironment = environment;
  }
  
  // For debugging - show current environment info
  static void logEnvironmentInfo() {
    if (kDebugMode) {
      print('🌍 Environment: $currentEnvironment');
      print('🔗 Base URL: $baseUrl');
      print('🗄️ Database URL: $databaseUrl');
      print('📋 Version: ${VersionControl.generateVersionNumber()}');
    }
  }
}
