// ignore_for_file: avoid_print
import 'dart:io';
import '../utils/version_control.dart';
import '../utils/version_config.dart';

class DeploymentService {
  static const String configFilePath = 'deployment_config.yaml';
  static const String versionHistoryPath = 'version_history.json';
  
  static Future<void> switchEnvironment(String newEnvironment) async {
    if (!VersionConfig.isValidEnvironment(newEnvironment)) {
      throw Exception('Invalid environment: $newEnvironment');
    }
    
    // Update version control environment
    await _updateVersionEnvironment(newEnvironment);
    
    // Update deployment configuration
    await _updateDeploymentConfig(newEnvironment);
    
    // Log environment switch
    await _logEnvironmentSwitch(newEnvironment);
    
    stdout.writeln('✅ Environment switched to: $newEnvironment');
    stdout.writeln('📍 New version: ${VersionControl.generateVersionNumber()}');
  }
  
  static Future<void> _updateVersionEnvironment(String environment) async {
    final versionFile = File('lib/utils/version_control.dart');
    if (!await versionFile.exists()) {
      throw Exception('Version control file not found');
    }
    
    String content = await versionFile.readAsString();
    content = content.replaceAll(
      "static const String environment = 'PROD';",
      "static const String environment = '$environment';"
    );
    
    await versionFile.writeAsString(content);
  }
  
  static Future<void> _updateDeploymentConfig(String environment) async {
    final config = {
      'environment': environment,
      'displayName': VersionConfig.getEnvironmentDisplayName(environment),
      'colors': VersionConfig.getEnvironmentColors(environment),
      'pipeline': VersionConfig.pipelineConfig[environment],
      'requiredApprovals': VersionConfig.requiredApprovals[environment],
      'timestamp': DateTime.now().toIso8601String(),
      'version': VersionControl.generateVersionNumber(),
    };
    
    final configFile = File(configFilePath);
    await configFile.writeAsString(_yamlToString(config));
  }
  
  static Future<void> _logEnvironmentSwitch(String environment) async {
    final historyFile = File(versionHistoryPath);
    List<Map<String, dynamic>> history = [];
    
    if (await historyFile.exists()) {
      final content = await historyFile.readAsString();
      try {
        history = List<Map<String, dynamic>>.from(
          // Parse JSON (simplified for this example)
          content.split('\n').where((line) => line.isNotEmpty).map((line) => {
            'timestamp': DateTime.now().toIso8601String(),
            'environment': environment,
            'version': VersionControl.generateVersionNumber(),
          }).toList()
        );
      } catch (e) {
        history = [];
      }
    }
    
    history.add({
      'timestamp': DateTime.now().toIso8601String(),
      'environment': environment,
      'version': VersionControl.generateVersionNumber(),
      'action': 'environment_switch',
    });
    
    await historyFile.writeAsString(_jsonToString(history));
  }
  
  static Future<Map<String, dynamic>?> getCurrentDeploymentConfig() async {
    final configFile = File(configFilePath);
    if (!await configFile.exists()) {
      return null;
    }
    
    final content = await configFile.readAsString();
    return _parseYaml(content);
  }
  
  static Future<void> validateDeployment(String environment, List<String> approvals) async {
    final requiredApprovals = VersionConfig.requiredApprovals[environment] ?? [];
    
    for (String approval in requiredApprovals) {
      if (!approvals.contains(approval)) {
        throw Exception('Missing required approval: $approval for $environment deployment');
      }
    }
    
    stdout.writeln('✅ Deployment validation passed for $environment');
  }
  
  static String _yamlToString(Map<String, dynamic> yaml) {
    String result = '';
    yaml.forEach((key, value) {
      result += '$key: ${_formatYamlValue(value)}\n';
    });
    return result;
  }
  
  static String _formatYamlValue(dynamic value) {
    if (value is String) return '"$value"';
    if (value is Map) {
      String result = '';
      value.forEach((k, v) {
        result += '    $k: ${_formatYamlValue(v)}\n';
      });
      return '\n$result';
    }
    if (value is List) {
      String result = '';
      for (var item in value) {
        result += '  - ${_formatYamlValue(item)}\n';
      }
      return '\n$result';
    }
    return value.toString();
  }
  
  static String _jsonToString(List<Map<String, dynamic>> json) {
    String result = '[\n';
    for (int i = 0; i < json.length; i++) {
      result += '  ${_mapToString(json[i])}';
      if (i < json.length - 1) result += ',';
      result += '\n';
    }
    result += ']';
    return result;
  }
  
  static String _mapToString(Map<String, dynamic> map) {
    String result = '{\n';
    map.forEach((key, value) {
      result += '    "$key": ${_formatJsonValue(value)},\n';
    });
    result += '  }';
    return result;
  }
  
  static String _formatJsonValue(dynamic value) {
    if (value is String) return '"$value"';
    if (value is Map || value is List) return value.toString();
    return value.toString();
  }
  
  static Map<String, dynamic> _parseYaml(String content) {
    // Simplified YAML parsing for this example
    final Map<String, dynamic> result = {};
    final lines = content.split('\n');
    
    for (String line in lines) {
      if (line.trim().isEmpty || line.startsWith('#')) continue;
      
      final parts = line.split(':');
      if (parts.length >= 2) {
        final key = parts[0].trim();
        final value = parts.sublist(1).join(':').trim();
        result[key] = value.replaceAll(RegExp(r'^"|"$'), '');
      }
    }
    
    return result;
  }
}
