import 'package:flutter/material.dart';
import 'stage_tracking_screen.dart';
import 'artifacts_overview_screen.dart';
import 'audit_trail_overview_screen.dart';

class DeliverablesMetricsScreen extends StatelessWidget {
  const DeliverablesMetricsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deliverables Metrics Overview'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildMetricCard(
            context,
            title: 'Stage Tracking',
            description: 'Track and update the stage of each deliverable (Draft, In Progress, Review, Signed Off).',
            icon: Icons.list_alt,
            color: Colors.blue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const StageTrackingScreen()),
            ),
          ),
          const SizedBox(height: 16),
          _buildMetricCard(
            context,
            title: 'Deliverable Artifacts',
            description: 'Browse and manage artifacts uploaded across all deliverables.',
            icon: Icons.folder_shared,
            color: Colors.orange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ArtifactsOverviewScreen()),
            ),
          ),
          const SizedBox(height: 16),
          _buildMetricCard(
            context,
            title: 'Audit Trail',
            description: 'Track changes and history for deliverables.',
            icon: Icons.history,
            color: Colors.purple,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AuditTrailOverviewScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
