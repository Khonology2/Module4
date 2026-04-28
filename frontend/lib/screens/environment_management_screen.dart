import 'package:flutter/material.dart';
import '../widgets/environment_switcher.dart';
import '../widgets/version_display.dart';

class EnvironmentManagementScreen extends StatelessWidget {
  const EnvironmentManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Environment Management'),
        backgroundColor: Colors.grey[900],
      ),
      backgroundColor: Colors.grey[950],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Environment Switcher
            const EnvironmentSwitcher(),
            
            const SizedBox(height: 24),
            
            // Version Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[400]),
                        const SizedBox(width: 8),
                        const Text(
                          'Version Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const VersionDisplay(),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Deployment Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.upload, color: Colors.green[400]),
                        const SizedBox(width: 8),
                        const Text(
                          'Deployment Instructions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInstructionItem(
                      '1. Switch Environment',
                      'Use the environment switcher above to change the deployment environment',
                      Icons.swap_horiz,
                    ),
                    _buildInstructionItem(
                      '2. Generate Version',
                      'Run: dart scripts/generate_version.dart',
                      Icons.code,
                    ),
                    _buildInstructionItem(
                      '3. Deploy Environment',
                      'Run: dart scripts/deploy_environment.dart <ENV>',
                      Icons.upload,
                    ),
                    _buildInstructionItem(
                      '4. Build Application',
                      'Run: flutter build web',
                      Icons.build,
                    ),
                    _buildInstructionItem(
                      '5. Deploy to Server',
                      'Upload build/web to your deployment server',
                      Icons.cloud_upload,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem(String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Colors.blue[400],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
