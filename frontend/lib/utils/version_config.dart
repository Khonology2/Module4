class VersionConfig {
  static const String currentVersion = '1.0.0';
  static const String buildNumber = '1';
  static const String environment = 'PROD';
  
  // Environment configurations
  static const Map<String, String> environments = {
    'DEV': 'Development Environment',
    'SIT': 'System Integration Testing',
    'UAT': 'User Acceptance Testing',
    'PROD': 'Production Environment',
  };
  
  // Environment-specific colors
  static const Map<String, Map<String, String>> environmentColors = {
    'DEV': {
      'background': '424242', // Dark grey
      'text': 'BDBDBD', // Light grey
    },
    'SIT': {
      'background': '212121', // Very dark grey
      'text': '9E9E9E', // Medium grey
    },
    'UAT': {
      'background': 'E65100', // Dark orange
      'text': 'FFFFFF', // White
    },
    'PROD': {
      'background': 'B71C1C', // Dark red
      'text': 'FFFFFF', // White
    },
  };
  
  // CI/CD pipeline configurations
  static const Map<String, String> pipelineConfig = {
    'DEV': 'dev',
    'SIT': 'sit',
    'UAT': 'uat', 
    'PROD': 'prod',
  };
  
  // Deployment validation rules
  static const Map<String, List<String>> requiredApprovals = {
    'PROD': ['senior-developer', 'tech-lead', 'devops'],
    'UAT': ['senior-developer', 'qa-lead'],
    'SIT': ['developer'],
    'DEV': ['developer'],
  };
  
  // Release increment rules
  static bool shouldIncrementRelease(String currentVersion, String changeType) {
    final releaseRules = {
      'bug-fix': true,
      'hotfix': true,
      'feature': false,
      'refactor': false,
      'config-change': false,
    };
    
    return releaseRules[changeType] ?? false;
  }
  
  // Environment validation
  static bool isValidEnvironment(String env) {
    return environments.containsKey(env);
  }
  
  // Get environment display name
  static String getEnvironmentDisplayName(String env) {
    return environments[env] ?? 'Unknown Environment';
  }
  
  // Get environment color scheme
  static Map<String, String> getEnvironmentColors(String env) {
    return environmentColors[env] ?? environmentColors['DEV']!;
  }
  
  static Map<String, dynamic> getVersionConfig() {
    return {
      'version': currentVersion,
      'buildNumber': buildNumber,
      'environment': environment,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
  
  static String getFullVersion() {
    return '$currentVersion+$buildNumber';
  }
  
  static bool isProduction() {
    return environment == 'PROD';
  }
  
  static bool isStaging() {
    return environment == 'UAT';
  }
  
  static bool isDevelopment() {
    return environment == 'DEV' || environment == 'SIT';
  }
}
