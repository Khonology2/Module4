import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SprintPerformanceChart extends StatelessWidget {
  final List<Map<String, dynamic>> sprints;
  final String chartType;

  const SprintPerformanceChart({
    super.key,
    required this.sprints,
    this.chartType = 'velocity',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getChartTitle(),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SizedBox(
                height: 200,
                child: _buildChart(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getChartTitle() {
    switch (chartType) {
      case 'velocity':
        return 'Velocity Trend';
      case 'burndown':
        return 'Burndown Chart';
      case 'burnup':
        return 'Burnup Chart';
      case 'defects':
        return 'Defect Trend';
      case 'test_pass_rate':
        return 'Test Pass Rate';
      case 'scope_change':
        return 'Scope Changes';
      case 'committed_vs_completed':
        return 'Committed vs Completed';
      default:
        return 'Performance Chart';
    }
  }

  Widget _buildChart() {
    switch (chartType) {
      case 'velocity':
        return _buildVelocityChart();
      case 'burndown':
        return _buildBurndownChart();
      case 'burnup':
        return _buildBurnupChart();
      case 'defects':
        return _buildDefectsChart();
      case 'test_pass_rate':
        return _buildTestPassRateChart();
      case 'scope_change':
        return _buildScopeChangeChart();
      case 'committed_vs_completed':
        return _buildCommittedVsCompletedChart();
      default:
        return _buildVelocityChart();
    }
  }

  Widget _buildVelocityChart() {
    final spots = <FlSpot>[];
    double maxY = 0;
    for (int i = 0; i < sprints.length; i++) {
      final sprint = sprints[i];
      final y = _toDouble(sprint['completed_points'] ?? sprint['velocity'] ?? sprint['completed'] ?? 0);
      if (y > maxY) maxY = y;
      spots.add(FlSpot(i.toDouble(), y));
    }

    final interval = maxY <= 10
        ? 2.0
        : maxY <= 50
            ? 5.0
            : 10.0;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY == 0 ? 10 : maxY * 1.2,
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: interval,
              getTitlesWidget: (value, meta) => Text(value.toInt().toString()),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i >= 0 && i < sprints.length) {
                  final label = _sprintLabel(i);
                  return Transform.rotate(
                    angle: -0.6,
                    child: Text(label, overflow: TextOverflow.ellipsis),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: const LineTouchData(enabled: true),
      ),
    );
  }

  Widget _buildBurndownChart() {
    final spots = <FlSpot>[];
    double maxY = 0;
    for (int i = 0; i < sprints.length; i++) {
      final sprint = sprints[i];
      final remaining = _toDouble(sprint['planned_points'] ?? 0) - _toDouble(sprint['completed_points'] ?? 0);
      if (remaining > maxY) maxY = remaining;
      spots.add(FlSpot(i.toDouble(), remaining));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: maxY <= 10 ? 2.0 : (maxY <= 50 ? 5.0 : 10.0),
              getTitlesWidget: (value, meta) => Text(value.toInt().toString()),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i >= 0 && i < sprints.length) {
                  final label = _sprintLabel(i);
                  return Transform.rotate(angle: -0.6, child: Text(label, overflow: TextOverflow.ellipsis));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.red,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  Widget _buildBurnupChart() {
    final spots = <FlSpot>[];
    double cumulative = 0;
    double maxY = 0;
    for (int i = 0; i < sprints.length; i++) {
      final sprint = sprints[i];
      cumulative += _toDouble(sprint['completed_points'] ?? 0);
      if (cumulative > maxY) maxY = cumulative;
      spots.add(FlSpot(i.toDouble(), cumulative));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: maxY <= 10 ? 2.0 : (maxY <= 50 ? 5.0 : 10.0),
              getTitlesWidget: (value, meta) => Text(value.toInt().toString()),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i >= 0 && i < sprints.length) {
                  final label = _sprintLabel(i);
                  return Transform.rotate(angle: -0.6, child: Text(label, overflow: TextOverflow.ellipsis));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.green,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefectsChart() {
    final spots = <FlSpot>[];
    double maxY = 0;
    for (int i = 0; i < sprints.length; i++) {
      final sprint = sprints[i];
      final defectCount = _toDouble(sprint['defects_opened'] ?? sprint['defect_count'] ?? 0);
      if (defectCount > maxY) maxY = defectCount;
      spots.add(FlSpot(i.toDouble(), defectCount));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: maxY <= 10 ? 2.0 : (maxY <= 50 ? 5.0 : 10.0),
              getTitlesWidget: (value, meta) => Text(value.toInt().toString()),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i >= 0 && i < sprints.length) {
                  final label = _sprintLabel(i);
                  return Transform.rotate(angle: -0.6, child: Text(label, overflow: TextOverflow.ellipsis));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.orange,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  Widget _buildTestPassRateChart() {
    final spots = <FlSpot>[];
    for (int i = 0; i < sprints.length; i++) {
      final sprint = sprints[i];
      double passRate = _toDouble(sprint['test_pass_rate'] ?? 0);
      if (passRate > 100) passRate = 100;
      if (passRate < 0) passRate = 0;
      spots.add(FlSpot(i.toDouble(), passRate));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 20,
              getTitlesWidget: (value, meta) => Text('${value.toInt()}%'),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i >= 0 && i < sprints.length) {
                  final label = _sprintLabel(i);
                  return Transform.rotate(angle: -0.6, child: Text(label, overflow: TextOverflow.ellipsis));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.purple,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.purple.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeChangeChart() {
    // Build bar chart showing points added vs removed per sprint
    final barGroups = <BarChartGroupData>[];
    
    for (int i = 0; i < sprints.length; i++) {
      final sprint = sprints[i];
      final pointsAdded = (sprint['points_added'] ?? 0).toDouble();
      final pointsRemoved = (sprint['points_removed'] ?? 0).toDouble();
      
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: pointsAdded,
              color: Colors.orange,
              width: 12,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            BarChartRodData(
              toY: pointsRemoved,
              color: Colors.blue,
              width: 12,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _getMaxScopeChange(),
              barGroups: barGroups,
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() < sprints.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('S${value.toInt() + 1}', style: const TextStyle(fontSize: 10)),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('Added', Colors.orange),
            const SizedBox(width: 16),
            _buildLegendItem('Removed', Colors.blue),
          ],
        ),
      ],
    );
  }

  Widget _buildCommittedVsCompletedChart() {
    final barGroups = <BarChartGroupData>[];
    
    for (int i = 0; i < sprints.length; i++) {
      final sprint = sprints[i];
      final committed = (sprint['planned_points'] ?? sprint['committed_points'] ?? 0).toDouble();
      final completed = (sprint['completed_points'] ?? 0).toDouble();
      
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: committed,
              color: Colors.blue.withValues(alpha: 0.6),
              width: 14,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            BarChartRodData(
              toY: completed,
              color: Colors.green,
              width: 14,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _getMaxPoints(),
              barGroups: barGroups,
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() < sprints.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Sprint ${value.toInt() + 1}', style: const TextStyle(fontSize: 10)),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('Committed', Colors.blue.withValues(alpha: 0.6)),
            const SizedBox(width: 16),
            _buildLegendItem('Completed', Colors.green),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  double _getMaxScopeChange() {
    double max = 10;
    for (final sprint in sprints) {
      final added = (sprint['points_added'] ?? 0).toDouble();
      final removed = (sprint['points_removed'] ?? 0).toDouble();
      if (added > max) max = added;
      if (removed > max) max = removed;
    }
    return max * 1.2;
  }

  double _getMaxPoints() {
    double max = 10;
    for (final sprint in sprints) {
      final committed = (sprint['planned_points'] ?? sprint['committed_points'] ?? 0).toDouble();
      final completed = (sprint['completed_points'] ?? 0).toDouble();
      if (committed > max) max = committed;
      if (completed > max) max = completed;
    }
    return max * 1.1;
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _sprintLabel(int index) {
    final s = sprints[index];
    final name = s['name']?.toString() ?? s['title']?.toString() ?? '';
    if (name.isNotEmpty) return name;
    final start = s['start_date']?.toString() ?? s['startDate']?.toString() ?? '';
    final end = s['end_date']?.toString() ?? s['endDate']?.toString() ?? '';
    if (start.isNotEmpty && end.isNotEmpty) return '${start.substring(0, 10)}→${end.substring(0, 10)}';
    return 'Sprint ${index + 1}';
  }
}

class SprintMetricsCard extends StatelessWidget {
  final Map<String, dynamic> sprint;

  const SprintMetricsCard({super.key, required this.sprint});

  @override
  Widget build(BuildContext context) {
    final plannedPoints = sprint['planned_points'] ?? 0;
    final completedPoints = sprint['completed_points'] ?? 0;
    final completionRate = plannedPoints > 0 ? (completedPoints / plannedPoints) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sprint Metrics',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Planned Points',
                    plannedPoints.toString(),
                    Icons.trending_up,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Completed Points',
                    completedPoints.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Completion Rate',
                    '${(completionRate * 100).toStringAsFixed(1)}%',
                    Icons.pie_chart,
                    _getCompletionColor(completionRate),
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Status',
                    sprint['status'] ?? 'Unknown',
                    Icons.flag,
                    _getStatusColor(sprint['status']),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: completionRate,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getCompletionColor(completionRate),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Color _getCompletionColor(double rate) {
    if (rate >= 1.0) return Colors.green;
    if (rate >= 0.8) return Colors.blue;
    if (rate >= 0.5) return Colors.orange;
    return Colors.red;
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'planning':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
