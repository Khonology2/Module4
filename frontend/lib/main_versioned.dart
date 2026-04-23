import 'package:flutter/material.dart';
import 'utils/version_control.dart';
import 'widgets/version_display.dart';
import 'services/version_service.dart';

void main() {
  runApp(const FlowSpaceApp());
}

class FlowSpaceApp extends StatelessWidget {
  const FlowSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flow Space - ${VersionService.getCurrentVersion()}',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const VersionedHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class VersionedHomePage extends StatelessWidget {
  const VersionedHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flow Space - ${VersionService.getCurrentVersion()}'),
        backgroundColor: _getEnvironmentColor(),
      ),
      body: Column(
        children: [
          const VersionBanner(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Application Version Information',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const VersionDisplay(),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        VersionControl.getFormattedVersionInfo(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getEnvironmentColor() {
    final environment = VersionService.getEnvironment();
    switch (environment) {
      case 'PROD':
        return Colors.red;
      case 'UAT':
        return Colors.orange;
      case 'SIT':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
