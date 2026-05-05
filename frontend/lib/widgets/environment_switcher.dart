import 'package:flutter/material.dart';
import '../services/deployment_service.dart';
import '../utils/version_config.dart';
import '../utils/version_control.dart';
import 'package:google_fonts/google_fonts.dart';

class EnvironmentSwitcher extends StatefulWidget {
  const EnvironmentSwitcher({super.key});

  @override
  State<EnvironmentSwitcher> createState() => _EnvironmentSwitcherState();
}

class _EnvironmentSwitcherState extends State<EnvironmentSwitcher> {
  String currentEnvironment = VersionConfig.environment;
  bool isDeploying = false;
  String? selectedEnvironment;
  bool isLoading = false;
  Map<String, dynamic>? currentConfig;

  @override
  void initState() {
    super.initState();
    currentConfig = {
      'environment': currentEnvironment,
    };
  }

  Future<void> _switchEnvironment(String environment) async {
    setState(() {
      isDeploying = true;
    });

    try {
      await DeploymentService.switchEnvironment(environment);
      
      if (mounted) {
        setState(() {
          currentEnvironment = environment;
          currentConfig = {'environment': environment};
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Environment switched to $environment'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isDeploying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings_suggest, color: Colors.blue[400]),
                const SizedBox(width: 8),
                const Text(
                  'Environment Control',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Current environment display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[600]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Environment',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        currentConfig?['environment'] ?? 'SIT',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getEnvironmentColor(currentConfig?['environment'] ?? 'SIT'),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          VersionControl.generateVersionNumber(),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Environment switcher
            const Text(
              'Switch Environment',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: VersionConfig.environments.keys.map((env) {
                final isCurrent = currentConfig?['environment'] == env;
                return ChoiceChip(
                  label: Text(env),
                  selected: isCurrent,
                  onSelected: isCurrent ? null : (selected) {
                    if (selected) {
                      setState(() {
                        selectedEnvironment = env;
                      });
                      _showSwitchConfirmation(env);
                    }
                  },
                  backgroundColor: Colors.grey[700],
                  selectedColor: _getEnvironmentColor(env),
                  labelStyle: TextStyle(
                    color: isCurrent ? Colors.white : Colors.grey[300],
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 20),
            
            // Environment info
            _buildEnvironmentInfo(),
            
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironmentInfo() {
    if (selectedEnvironment == null) {
      return const SizedBox.shrink();
    }
    
    final env = selectedEnvironment!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected Environment: $env',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Display Name: ${VersionConfig.getEnvironmentDisplayName(env)}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Required Approvals: ${VersionConfig.requiredApprovals[env]?.join(", ") ?? "None"}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Color _getEnvironmentColor(String env) {
    switch (env) {
      case 'PROD':
        return Colors.red[900] ?? Colors.red;
      case 'UAT':
        return Colors.orange[900] ?? Colors.orange;
      case 'SIT':
        return Colors.grey[700] ?? Colors.grey;
      default:
        return Colors.grey[600] ?? Colors.grey;
    }
  }

  void _showSwitchConfirmation(String environment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Switch to $environment?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will change the application environment to:'),
            const SizedBox(height: 8),
            Text(
              VersionConfig.getEnvironmentDisplayName(environment),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('New version will be: ${VersionControl.generateVersionNumber()}'),
            const SizedBox(height: 16),
            const Text('⚠️ This action will restart the application.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _switchEnvironment(environment);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _getEnvironmentColor(environment),
            ),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
  }
}
