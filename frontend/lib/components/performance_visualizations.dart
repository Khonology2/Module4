import 'package:flutter/material.dart';

class PerformanceVisualizations extends StatelessWidget {
  final double cpuUsage;
  final double memoryUsage;
  final double diskUsage;

  const PerformanceVisualizations({
    super.key,
    required this.cpuUsage,
    required this.memoryUsage,
    required this.diskUsage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _UsageBar(label: 'CPU', percent: _normalize(cpuUsage)),
        const SizedBox(height: 10),
        _UsageBar(label: 'Memory', percent: _normalize(memoryUsage)),
        const SizedBox(height: 10),
        _UsageBar(label: 'Disk', percent: _normalize(diskUsage)),
      ],
    );
  }

  double _normalize(double value) {
    if (value < 0) return 0;
    if (value > 100) return 100;
    return value;
  }
}

class _UsageBar extends StatelessWidget {
  final String label;
  final double percent;

  const _UsageBar({required this.label, required this.percent});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(percent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Text(
              '${percent.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: percent / 100,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Color _statusColor(double value) {
    if (value >= 90) return Colors.red;
    if (value >= 70) return Colors.orange;
    return Colors.green;
  }
}