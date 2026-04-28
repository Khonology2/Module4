// ignore_for_file: non_constant_identifier_names, unused_import

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../components/performance_visualizations.dart';
import '../services/dashboard_service.dart';
import '../widgets/metrics_card.dart';
import '../widgets/sprint_performance_chart.dart';

class PerformanceDashboardScreen extends StatefulWidget {
  const PerformanceDashboardScreen({super.key});

  @override
  State<PerformanceDashboardScreen> createState() => _PerformanceDashboardScreenState();
}

class _PerformanceDashboardScreenState extends State<PerformanceDashboardScreen> {
  Map<String, dynamic> _performanceData = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPerformanceData();
  }

  Future<void> _loadPerformanceData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await DashboardService().getDashboardData();
      final data = response.data ?? {};
      
      setState(() {
        _performanceData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load performance data: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading performance data...'),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Unknown error occurred',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPerformanceData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    final sprints = _performanceData['sprints'] as List? ?? [];
    final sprintStats = _performanceData['sprint_stats'] as List? ?? [];
    final userActivity = _performanceData['user_activity'] as Map? ?? {};

    final totalSprints = sprints.length;
    final completedSprints = sprints.where((s) => s['status'] == 'completed').length;
    final avgVelocity = sprintStats.isNotEmpty
        ? sprintStats.map((s) => s['completed_points'] ?? 0).reduce((a, b) => a + b) / sprintStats.length
        : 0;
    final avgTestPassRate = sprints.isNotEmpty
        ? sprints.map((s) => s['test_pass_rate'] ?? 0).reduce((a, b) => a + b) / sprints.length
        : 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MetricsCard(
                title: 'Total Sprints',
                value: totalSprints.toString(),
                icon: Icons.timeline,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricsCard(
                title: 'Completed',
                value: completedSprints.toString(),
                icon: Icons.check_circle,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricsCard(
                title: 'Avg Velocity',
                value: avgVelocity.toStringAsFixed(1),
                icon: Icons.speed,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricsCard(
                title: 'Test Pass %',
                value: '${avgTestPassRate.toStringAsFixed(1)}%',
                icon: Icons.science,
                color: Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: MetricsCard(
                title: 'Active Users',
                value: (userActivity['active_users'] ?? 0).toString(),
                icon: Icons.people,
                color: Colors.teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricsCard(
                title: 'Daily Actions',
                value: (userActivity['daily_actions'] ?? 0).toString(),
                icon: Icons.touch_app,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricsCard(
                title: 'Defect Rate',
                value: '${((userActivity['defect_rate'] ?? 0) * 100).toStringAsFixed(1)}%',
                icon: Icons.bug_report,
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricsCard(
                title: 'Review Time',
                value: '${(userActivity['avg_review_time'] ?? 0).toStringAsFixed(1)}h',
                icon: Icons.schedule,
                color: Colors.blueGrey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSprintPerformance() {
    final sprints = _performanceData['sprints'] as List? ?? [];
    
    if (sprints.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No sprint data available'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sprint Performance Overview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: SprintPerformanceChart(
                sprints: sprints.map((sprint) {
                  return {
                    'id': sprint['id'],
                    'name': sprint['name'],
                    'start_date': sprint['start_date'],
                    'end_date': sprint['end_date'],
                    'planned_points': sprint['committed_points'],
                    'completed_points': sprint['completed_points'],
                    'status': sprint['status'],
                  };
                }).toList(),
                chartType: 'velocity',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceVisualizations() {
    return PerformanceVisualizations(dashboardData: _performanceData);
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Performance Dashboard',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadPerformanceData,
                tooltip: 'Refresh Data',
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildPerformanceMetrics(),
          const SizedBox(height: 24),

          _buildSprintPerformance(),
          const SizedBox(height: 24),

          _buildPerformanceVisualizations(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard),
            onPressed: () => context.go('/dashboard'),
            tooltip: 'Main Dashboard',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }
  
  Widget PerformanceVisualizations({required Map<String, dynamic> dashboardData}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Visualizations',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'Performance visualization charts will be displayed here',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
  

}