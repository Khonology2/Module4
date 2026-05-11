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
  int _liveActionCount = 0;
  

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
      final data = await ApiService.getSystemMetrics();
      var metrics = _toSystemMetrics(data);
      final mergedSessions = _liveActionCount > metrics.userActivity.totalSessions
          ? _liveActionCount
          : metrics.userActivity.totalSessions;
      final mergedActiveUsers =
          _activeUserIds.isNotEmpty ? _activeUserIds.length : metrics.userActivity.activeUsers;
      if (mergedSessions != metrics.userActivity.totalSessions || mergedActiveUsers != metrics.userActivity.activeUsers) {
        metrics = SystemMetrics(
          systemHealth: metrics.systemHealth,
          performance: metrics.performance,
          database: metrics.database,
          userActivity: UserActivityMetrics(
            activeUsers: mergedActiveUsers,
            totalSessions: mergedSessions,
            newRegistrations: metrics.userActivity.newRegistrations,
            failedLogins: metrics.userActivity.failedLogins,
            avgSessionDuration: metrics.userActivity.avgSessionDuration,
          ),
          lastUpdated: metrics.lastUpdated,
        );
      }
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
      for (final evt in <String>[
        'project_created',
        'project_updated',
        'sprint_created',
        'sprint_updated',
        'deliverable_created',
        'deliverable_updated',
        'report_submitted',
        'report_approved',
        'report_change_requested',
        'notification_received',
      ]) {
        _realtime!.on(evt, (_) {
          _liveActionCount++;
          if (_metrics != null && mounted) {
            setState(() {
              _metrics = SystemMetrics(
                systemHealth: _metrics!.systemHealth,
                performance: _metrics!.performance,
                database: _metrics!.database,
                userActivity: UserActivityMetrics(
                  activeUsers: _activeUserIds.isNotEmpty ? _activeUserIds.length : _metrics!.userActivity.activeUsers,
                  totalSessions: _liveActionCount > _metrics!.userActivity.totalSessions
                      ? _liveActionCount
                      : _metrics!.userActivity.totalSessions,
                  newRegistrations: _metrics!.userActivity.newRegistrations,
                  failedLogins: _metrics!.userActivity.failedLogins,
                  avgSessionDuration: _metrics!.userActivity.avgSessionDuration,
                ),
                lastUpdated: DateTime.now(),
              );
            });
          }
          _loadMetrics();
        });
      }
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

    Map<String, dynamic> asMap(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return <String, dynamic>{};
    }

    double asDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      if (v is String) {
        final t = v.trim();
        if (t.isEmpty) return 0.0;
        final normalized = t.replaceAll(',', '');
        final match = RegExp(r'-?\d+(\.\d+)?').firstMatch(normalized);
        if (match == null) return 0.0;
        return double.tryParse(match.group(0)!) ?? 0.0;
      }
      return 0.0;
    }

    int asInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is num) return v.toInt();
      if (v is String) {
        final t = v.trim();
        if (t.isEmpty) return 0;
        final normalized = t.replaceAll(',', '');
        final match = RegExp(r'-?\d+').firstMatch(normalized);
        if (match == null) return 0;
        return int.tryParse(match.group(0)!) ?? 0;
      }
      return 0;
    }

    double pickDouble(List<dynamic> values) {
      for (final v in values) {
        if (v == null) continue;
        final parsed = asDouble(v);
        if (parsed != 0.0 || v == 0 || v == 0.0 || v == '0' || v == '0.0') return parsed;
      }
      return 0.0;
    }

    int pickInt(List<dynamic> values) {
      for (final v in values) {
        if (v == null) continue;
        final parsed = asInt(v);
        if (parsed != 0 || v == 0 || v == '0') return parsed;
      }
      return 0;
    }

    SystemHealthStatus pickHealth() {
      final raw = (d['systemHealth'] ?? d['health'] ?? d['status'] ?? '')
          .toString()
          .toLowerCase()
          .trim();
      if (raw.contains('critical') || raw.contains('down') || raw.contains('error')) {
        return SystemHealthStatus.critical;
      }
      if (raw.contains('degraded') || raw.contains('warn')) {
        return SystemHealthStatus.degraded;
      }
      return SystemHealthStatus.healthy;
    }

    final system = asMap(d['system']);
    final statistics = asMap(d['statistics'] ?? d['stats']);
    final systemUsage = asMap(system['system_usage'] ?? system['systemUsage'] ?? d['system_usage'] ?? d['systemUsage']);
    final perfRaw = asMap(d['performance'] ?? d['performance_metrics'] ?? systemUsage);
    final userActivityRaw = asMap(d['user_activity'] ?? d['userActivity'] ?? statistics['user_activity'] ?? statistics['userActivity']);
    final databaseRaw = asMap(d['database'] ?? d['db'] ?? d['database_metrics'] ?? d['databaseMetrics']);

    final perf = PerformanceMetrics(
      cpuUsage: pickDouble([
        d['cpuUsage'],
        d['cpu_usage'],
        systemUsage['cpuUsage'],
        systemUsage['cpu_usage'],
        systemUsage['cpu_percent'],
        perfRaw['cpuUsage'],
        perfRaw['cpu_percent'],
        perfRaw['cpu'],
      ]),
      memoryUsage: pickDouble([
        d['memoryUsage'],
        d['memory_usage'],
        systemUsage['memoryUsage'],
        systemUsage['memory_usage'],
        systemUsage['memory_used_mb'],
        perfRaw['memoryUsage'],
        perfRaw['memory_used_mb'],
        perfRaw['memory_mb'],
      ]),
      diskUsage: pickDouble([
        d['diskUsage'],
        d['disk_usage'],
        systemUsage['diskUsage'],
        systemUsage['disk_usage'],
        systemUsage['disk_percent'],
        perfRaw['diskUsage'],
        perfRaw['disk_percent'],
        perfRaw['disk'],
      ]),
      responseTime: pickInt([
        d['responseTime'],
        d['response_time'],
        systemUsage['responseTime'],
        systemUsage['response_time'],
        perfRaw['avg_response_time_ms'],
        perfRaw['response_time_ms'],
      ]),
      uptime: pickDouble([
        d['uptime'],
        systemUsage['uptime'],
        systemUsage['uptime_seconds'],
        perfRaw['uptime'],
        perfRaw['uptime_seconds'],
      ]),
    );

    double normalizePercent(double v) {
      if (v > 0 && v <= 1.0) return v * 100.0;
      return v;
    }

    double normalizeMb(double v) {
      if (v >= 1024 * 1024) return v / (1024 * 1024);
      if (v >= 1024 * 10 && v < 1024 * 1024) return v / 1024;
      return v;
    }

    final normalizedPerf = PerformanceMetrics(
      cpuUsage: normalizePercent(perf.cpuUsage),
      memoryUsage: normalizeMb(perf.memoryUsage),
      diskUsage: normalizePercent(perf.diskUsage),
      responseTime: perf.responseTime,
      uptime: perf.uptime,
    );

    final db = DatabaseMetrics(
      totalRecords: pickInt([
        d['totalUsers'],
        d['users'],
        statistics['users'],
        statistics['total_users'],
        statistics['totalUsers'],
        databaseRaw['totalUsers'],
        databaseRaw['users'],
        d['totalEntities'],
        d['total_records'],
        statistics['totalEntities'],
        statistics['total_entities'],
      ]),
      activeConnections: pickInt([
        d['activeConnections'],
        d['active_connections'],
        system['activeConnections'],
        system['active_connections'],
        databaseRaw['activeConnections'],
        databaseRaw['active_connections'],
      ]),
      cacheHitRatio: pickDouble([
        d['cacheHitRatio'],
        d['cache_hit_ratio'],
        system['cacheHitRatio'],
        system['cache_hit_ratio'],
        databaseRaw['cacheHitRatio'],
        databaseRaw['cache_hit_ratio'],
      ]),
      queryCount: pickInt([
        d['queryCount'],
        d['query_count'],
        system['queryCount'],
        system['query_count'],
        databaseRaw['queryCount'],
        databaseRaw['query_count'],
      ]),
      slowQueries: pickInt([
        d['slowQueries'],
        d['slow_queries'],
        system['slowQueries'],
        system['slow_queries'],
        databaseRaw['slowQueries'],
        databaseRaw['slow_queries'],
      ]),
    );

    final normalizedDb = DatabaseMetrics(
      totalRecords: db.totalRecords,
      activeConnections: db.activeConnections,
      cacheHitRatio: normalizePercent(db.cacheHitRatio),
      queryCount: db.queryCount,
      slowQueries: db.slowQueries,
    );

    final ua = UserActivityMetrics(
      activeUsers: pickInt([
        d['activeUsers'],
        d['active_users'],
        d['active_users_24h'],
        userActivityRaw['activeUsers'],
        userActivityRaw['active_users'],
        userActivityRaw['active_users_24h'],
        statistics['active_users'],
        statistics['active_users_24h'],
      ]),
      totalSessions: pickInt([
        d['totalSessions'],
        d['total_sessions'],
        userActivityRaw['totalSessions'],
        userActivityRaw['total_sessions'],
        system['totalSessions'],
        system['total_sessions'],
      ]),
      newRegistrations: pickInt([
        d['newRegistrations'],
        d['new_users'],
        userActivityRaw['newRegistrations'],
        userActivityRaw['new_users'],
        system['newRegistrations'],
        system['new_registrations'],
      ]),
      failedLogins: pickInt([
        d['failedLogins'],
        d['failed_logins'],
        userActivityRaw['failedLogins'],
        userActivityRaw['failed_logins'],
        system['failedLogins'],
        system['failed_logins'],
      ]),
      avgSessionDuration: pickDouble([
        d['avgSessionDuration'],
        d['avg_session_duration'],
        userActivityRaw['avgSessionDuration'],
        userActivityRaw['avg_session_duration'],
        system['avgSessionDuration'],
        system['avg_session_duration'],
      ]),
    );

    return SystemMetrics(
      systemHealth: pickHealth(),
      performance: normalizedPerf,
      database: normalizedDb,
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('System Metrics Dashboard'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
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
