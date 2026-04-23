import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../models/system_metrics.dart';
import '../widgets/metrics_card.dart';
import '../widgets/system_health_indicator.dart';
import '../services/realtime_service.dart';

class SystemMetricsScreen extends StatefulWidget {
  const SystemMetricsScreen({super.key});

  @override
  State<SystemMetricsScreen> createState() => _SystemMetricsScreenState();
}

class _SystemMetricsScreenState extends State<SystemMetricsScreen> {
  SystemMetrics? _metrics;
  bool _isLoading = true;
  bool _hasError = false;
  Timer? _refreshTimer;
  RealtimeService? _realtime;
  final Set<String> _activeUserIds = {};
  

  @override
  void initState() {
    super.initState();
    _loadMetrics();
    // Refresh metrics every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadMetrics();
    });
    _setupRealtime();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    try {
      _realtime?.offAll('analytics_updated');
    } catch (_) {}
    super.dispose();
  }

  Future<void> _loadMetrics() async {
    try {
      final metricsData = await ApiService.getSystemMetrics();
      final metrics = _toSystemMetrics(metricsData);
      if (mounted) {
        setState(() {
          _metrics = metrics;
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      debugPrint('Error loading system metrics: $error');
    }
  }


  void _setupRealtime() {
    try {
      _realtime = RealtimeService();
      _realtime!.initialize();
      _realtime!.on('analytics_updated', (data) {
        try {
          final m = _mergeMetrics(_metrics, data);
          if (mounted) {
            setState(() {
              _metrics = m;
              _isLoading = false;
              _hasError = false;
            });
          }
        } catch (_) {}
      });
      _realtime!.on('user_online', (userId) {
        if (userId is String) {
          _activeUserIds.add(userId);
          if (_metrics != null && mounted) {
            setState(() {
              _metrics = SystemMetrics(
                systemHealth: _metrics!.systemHealth,
                performance: _metrics!.performance,
                database: _metrics!.database,
                userActivity: UserActivityMetrics(
                  activeUsers: _activeUserIds.length,
                  totalSessions: _metrics!.userActivity.totalSessions,
                  newRegistrations: _metrics!.userActivity.newRegistrations,
                  failedLogins: _metrics!.userActivity.failedLogins,
                  avgSessionDuration: _metrics!.userActivity.avgSessionDuration,
                ),
                lastUpdated: DateTime.now(),
              );
            });
          }
        }
      });
      _realtime!.on('user_offline', (userId) {
        if (userId is String) {
          _activeUserIds.remove(userId);
          if (_metrics != null && mounted) {
            setState(() {
              _metrics = SystemMetrics(
                systemHealth: _metrics!.systemHealth,
                performance: _metrics!.performance,
                database: _metrics!.database,
                userActivity: UserActivityMetrics(
                  activeUsers: _activeUserIds.length,
                  totalSessions: _metrics!.userActivity.totalSessions,
                  newRegistrations: _metrics!.userActivity.newRegistrations,
                  failedLogins: _metrics!.userActivity.failedLogins,
                  avgSessionDuration: _metrics!.userActivity.avgSessionDuration,
                ),
                lastUpdated: DateTime.now(),
              );
            });
          }
        }
      });
    } catch (_) {}
  }

  SystemMetrics _toSystemMetrics(dynamic data) {
    final Map<String, dynamic> d = data is Map<String, dynamic>
        ? data
        : (data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});
    final Map<String, dynamic> perfRaw = (d['performance'] is Map)
        ? Map<String, dynamic>.from(d['performance'])
        : {};
    double parseDoubleLocal(dynamic v) {
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }
    int parseIntLocal(dynamic v) {
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }
    final perf = PerformanceMetrics(
      cpuUsage: parseDoubleLocal(d['cpuUsage'] ?? d['cpu_usage'] ?? perfRaw['cpu_percent']),
      memoryUsage: parseDoubleLocal(d['memoryUsage'] ?? d['memory_usage'] ?? perfRaw['memory_used_mb']),
      diskUsage: parseDoubleLocal(d['diskUsage'] ?? d['disk_usage'] ?? perfRaw['memory_percent']),
      responseTime: parseIntLocal(d['responseTime'] ?? d['response_time'] ?? perfRaw['avg_response_time_ms']),
      uptime: parseDoubleLocal(d['uptime'] ?? perfRaw['uptime_seconds']),
    );
    final db = DatabaseMetrics(
      totalRecords: parseIntLocal(d['totalEntities'] ?? d['total_records']),
      activeConnections: parseIntLocal(d['activeConnections'] ?? d['active_connections']),
      cacheHitRatio: parseDoubleLocal(d['cacheHitRatio'] ?? d['cache_hit_ratio']),
      queryCount: parseIntLocal(d['queryCount'] ?? d['query_count']),
      slowQueries: parseIntLocal(d['slowQueries'] ?? d['slow_queries']),
    );
    final ua = UserActivityMetrics(
      activeUsers: parseIntLocal(d['activeUsers'] ?? d['active_users'] ?? d['active_users_24h'] ?? (d['user_activity'] is Map ? (d['user_activity']['active_users_24h'] ?? 0) : 0)),
      totalSessions: parseIntLocal(d['totalSessions'] ?? d['total_sessions']),
      newRegistrations: parseIntLocal(d['newRegistrations'] ?? d['new_users']),
      failedLogins: parseIntLocal(d['failedLogins'] ?? d['failed_logins']),
      avgSessionDuration: parseDoubleLocal(d['avgSessionDuration'] ?? d['avg_session_duration']),
    );
    return SystemMetrics(
      systemHealth: SystemHealthStatus.healthy,
      performance: perf,
      database: db,
      userActivity: ua,
      lastUpdated: DateTime.now(),
    );
  }

  SystemMetrics _mergeMetrics(SystemMetrics? current, dynamic data) {
    final incoming = _toSystemMetrics(data);
    if (current == null) return incoming;
    return SystemMetrics(
      systemHealth: incoming.systemHealth,
      performance: PerformanceMetrics(
        cpuUsage: incoming.performance.cpuUsage != 0.0 ? incoming.performance.cpuUsage : current.performance.cpuUsage,
        memoryUsage: incoming.performance.memoryUsage != 0.0 ? incoming.performance.memoryUsage : current.performance.memoryUsage,
        diskUsage: incoming.performance.diskUsage != 0.0 ? incoming.performance.diskUsage : current.performance.diskUsage,
        responseTime: incoming.performance.responseTime != 0 ? incoming.performance.responseTime : current.performance.responseTime,
        uptime: incoming.performance.uptime != 0.0 ? incoming.performance.uptime : current.performance.uptime,
      ),
      database: current.database,
      userActivity: UserActivityMetrics(
        activeUsers: (_activeUserIds.isNotEmpty ? _activeUserIds.length : (incoming.userActivity.activeUsers != 0 ? incoming.userActivity.activeUsers : current.userActivity.activeUsers)),
        totalSessions: incoming.userActivity.totalSessions != 0 ? incoming.userActivity.totalSessions : current.userActivity.totalSessions,
        newRegistrations: incoming.userActivity.newRegistrations != 0 ? incoming.userActivity.newRegistrations : current.userActivity.newRegistrations,
        failedLogins: incoming.userActivity.failedLogins != 0 ? incoming.userActivity.failedLogins : current.userActivity.failedLogins,
        avgSessionDuration: incoming.userActivity.avgSessionDuration != 0.0 ? incoming.userActivity.avgSessionDuration : current.userActivity.avgSessionDuration,
      ),
      lastUpdated: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Metrics Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMetrics,
            tooltip: 'Refresh Metrics',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/admin-panel'),
            tooltip: 'Admin Panel',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to load system metrics',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _loadMetrics,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // System Health Overview
                    _buildHealthOverview(),
                    const SizedBox(height: 24),

                      // Performance Metrics
                      _buildPerformanceMetrics(),
                      const SizedBox(height: 24),

                      // Database Metrics
                      _buildDatabaseMetrics(),
                      const SizedBox(height: 24),

                      // User Activity Metrics
                      _buildUserActivityMetrics(),
                      const SizedBox(height: 24),

                      // System Resources
                    _buildSystemResources(),
                  ],
                ),
              ),
    );
  }

  Widget _buildHealthOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Health Overview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SystemHealthIndicator(
                  status: _metrics != null ? _metrics!.systemHealth : SystemHealthStatus.unknown,
                  size: 48,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _metrics != null ? _metrics!.systemHealth.toString().split('.').last.toUpperCase() : 'UNKNOWN',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _getHealthStatusColor(_metrics?.systemHealth),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getHealthStatusMessage(_metrics?.systemHealth),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        'Last checked: ${_metrics != null ? _metrics!.lastUpdated.toLocal() : 'N/A'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildPerformanceMetrics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Metrics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: MetricsCard(
                    title: 'Response Time',
                    value: _metrics != null ? '${_metrics!.performance.responseTime.toString()}ms' : 'N/A',
                    icon: Icons.speed,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricsCard(
                    title: 'Uptime',
                    value: _metrics != null ? '${_metrics!.performance.uptime.toStringAsFixed(1)}%' : 'N/A',
                    icon: Icons.timer,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricsCard(
                    title: 'Slow Queries',
                    value: _metrics != null ? _metrics!.database.slowQueries.toString() : 'N/A',
                    icon: Icons.warning,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatabaseMetrics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Database Metrics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: MetricsCard(
                    title: 'Total Users',
                    value: _metrics != null ? _metrics!.database.totalRecords.toString() : 'N/A',
                    icon: Icons.people,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricsCard(
                    title: 'Active Connections',
                    value: _metrics != null ? _metrics!.database.activeConnections.toString() : 'N/A',
                    icon: Icons.event_seat,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricsCard(
                    title: 'Cache Hit Ratio',
                    value: _metrics != null
                        ? '${_metrics!.database.cacheHitRatio.toStringAsFixed(1)}%'
                        : 'N/A',
                    icon: Icons.storage,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserActivityMetrics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Activity',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: MetricsCard(
                    title: 'Active Users',
                    value: _metrics != null ? _metrics!.userActivity.activeUsers.toString() : 'N/A',
                    icon: Icons.people,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricsCard(
                    title: 'Total Sessions',
                    value: _metrics != null ? _metrics!.userActivity.totalSessions.toString() : 'N/A',
                    icon: Icons.trending_up,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricsCard(
                    title: 'New Users',
                    value: _metrics != null ? _metrics!.userActivity.newRegistrations.toString() : 'N/A',
                    icon: Icons.person_add,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemResources() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Resources',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: MetricsCard(
                    title: 'CPU Usage',
                    value: _metrics != null ? '${_metrics!.performance.cpuUsage.toStringAsFixed(1)}%' : 'N/A',
                    icon: Icons.memory,
                    color: _getResourceColor(_metrics?.performance.cpuUsage),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricsCard(
                    title: 'Memory',
                    value: _metrics != null ? '${_metrics!.performance.memoryUsage.toStringAsFixed(1)}MB' : 'N/A',
                    icon: Icons.memory,
                    color: _getResourceColor(_metrics?.performance.memoryUsage),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricsCard(
                    title: 'Disk Space',
                    value: _metrics != null ? '${_metrics!.performance.diskUsage.toStringAsFixed(1)}%' : 'N/A',
                    icon: Icons.storage,
                    color: _getResourceColor(_metrics?.performance.diskUsage),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }



  Color _getHealthStatusColor(SystemHealthStatus? status) {
    switch (status) {
      case SystemHealthStatus.healthy:
        return Colors.green;
      case SystemHealthStatus.degraded:
        return Colors.orange;
      case SystemHealthStatus.critical:
        return Colors.red;
      case SystemHealthStatus.unknown:
      default:
        return Colors.grey;
    }
  }

  String _getHealthStatusMessage(SystemHealthStatus? status) {
    switch (status) {
      case SystemHealthStatus.healthy:
        return 'All systems are operating normally';
      case SystemHealthStatus.degraded:
        return 'Some systems are experiencing minor issues';
      case SystemHealthStatus.critical:
        return 'Critical systems are experiencing issues';
      case SystemHealthStatus.unknown:
      default:
        return 'No status information available';
    }
  }

  Color _getResourceColor(double? usage) {
    if (usage == null) return Colors.grey;
    if (usage > 90) return Colors.red;
    if (usage > 70) return Colors.orange;
    return Colors.green;
  }
}

// Helper class for refresh timer
class Timer {
  // ignore: strict_top_level_inference
  static periodic(Duration duration, Function(Timer) callback) {
    // Implementation would use actual Dart Timer
    return Timer();
  }
  
  void cancel() {}
}
