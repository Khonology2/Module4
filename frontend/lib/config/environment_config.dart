class EnvironmentConfig {
  static const String baseUrl = 'http://localhost:3001';

  // Environment-specific configurations
  static Map<String, Map<String, String>> get environmentConfigs => {
        'DEV': {
          'baseUrl': 'http://localhost:3001',
          'databaseUrl': 'postgresql://localhost:5432/flowspace_dev',
          'environment': 'Development',
        },
        'SIT': {
          'baseUrl': 'http://localhost:3001',
          'databaseUrl': 'postgresql://localhost:5432/flowspace_sit',
          'environment': 'System Integration Testing',
        },
        'UAT': {
          'baseUrl': 'https://uat-api.flownet.works',
          'databaseUrl': 'postgresql://uat-db.flownet.works:5432/flowspace_uat',
          'environment': 'User Acceptance Testing',
        },
        'PROD': {
          'baseUrl': 'https://api.flownet.works',
          'databaseUrl': 'postgresql://prod-db.flownet.works:5432/flowspace',
          'environment': 'Production',
        },
      };

  static Map<String, String> getCurrentConfig(String environment) {
    return environmentConfigs[environment] ?? environmentConfigs['SIT']!;
  }

  static String getBaseUrl(String environment) {
    return getCurrentConfig(environment)['baseUrl'] ?? baseUrl;
  }

  static String getDatabaseUrl(String environment) {
    return getCurrentConfig(environment)['databaseUrl'] ?? '';
  }

  static String getEnvironmentDisplayName(String environment) {
    return getCurrentConfig(environment)['environment'] ?? 'Unknown';
  }
}
